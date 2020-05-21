#!/usr/bin/env python38

"""
Fetches the latest testing versions and builds a Nix expressions with package
overrides to install them. Then rebuilds the system.

The output file is a NixOS module that is automatically imported by the webhook
module, if present.
"""

import hashlib
import json
import os
import subprocess
from base64 import b64encode
from os.path import basename
from tempfile import TemporaryDirectory
from time import sleep
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def call_github(resource, body=None):
    """Make a request to the GitHub API."""
    url = f'https://api.github.com{resource}'
    data = None
    headers = dict(request_headers)
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    with urlopen(Request(url, data, headers)) as f:
        return json.loads(f.read())


def nix_download(url):
    """Download a GitHub file to the Nix store, and return the SRI hash."""
    filename = basename(urlparse(url).path)
    with TemporaryDirectory() as tmpdir:
        filepath = f'{tmpdir}/{filename}'
        with open(filepath, "wb") as tmpfile:
            with urlopen(Request(url, None, request_headers)) as download:
                hasher = hashlib.sha256()
                while True:
                    chunk = download.read(65536)
                    if not chunk:
                        break
                    hasher.update(chunk)
                    tmpfile.write(chunk)
        subprocess.run(
            ['nix-store', '--add-fixed', 'sha256', filepath],
            check=True
        )
    return 'sha256-' + b64encode(hasher.digest()).decode()


def make_section(name, content):
    """Format a section containing multiline text."""
    start = f"### Begin section: {name}"
    end = f"### End section: {name}"
    return start + "\n" + content.strip() + "\n" + end + "\n"


def extract_section(text, name):
    """Extract a section from multiline text."""
    lines = text.splitlines()
    try:
        start = lines.index(f'### Begin section: {name}')
        end = lines.index(f'### End section: {name}', start + 1)
        return "\n".join(lines[start+1:end])
    except ValueError:
        return ""


# Delay for a little bit.
#
# We do this because we require successful completion of checks on GitHub,
# but the webhook is also triggered at the end those checks.
sleep(10)

# Read the existing config.
config_path = '/etc/nixos/support/webhook/generated.nix'
try:
    with open(config_path, 'r') as f:
        existing = f.read()
except FileNotFoundError:
    existing = ''

# Default GitHub request headers.
with open('/private/github-token.txt', 'r') as f:
    request_headers = {
        'User-Agent': 'portier webhook',
        'Authorization': 'Bearer ' + f.read().strip()
    }

# Query latest commits.
query = """\
{
  broker: repository(owner: "portier", name: "portier-broker") {
    defaultBranchRef {
      target {
        ... on Commit {
          oid
        }
      }
    }
  }
  demo: repository(owner: "portier", name: "demo-rp") {
    defaultBranchRef {
      target {
        ... on Commit {
          oid
          tarballUrl
        }
      }
    }
  }
}
"""
response = call_github('/graphql', {'query': query})

# If the commit hash appears in the existing section, we don't have to update.
# Otherwise, fetch the latest build artifact so we can determine the hash, and
# add it to the store so we don't have to download it again.
broker_head = response['data']['broker']['defaultBranchRef']['target']
broker_section = extract_section(existing, "portier/portier-broker")
if broker_head['oid'] in broker_section:
    print('No change to portier/portier-broker')
else:
    print('Preparing deploy of portier/portier-broker ' + broker_head['oid'])

    runs_resource = (
        '/repos/portier/portier-broker/actions/workflows/build.yml/runs' +
        '?branch=master&status=success&per_page=5'
    )
    runs = call_github(runs_resource)
    run_id = next(
        (run['id'] for run in runs['workflow_runs']
            if run['head_sha'] == broker_head['oid']),
        None
    )

    if run_id is None:
        print("Could not find a successful workflow run")
    else:
        artifacts_resource = (
            f'/repos/portier/portier-broker/actions/runs/{run_id}/artifacts'
        )
        artifacts = call_github(artifacts_resource)
        zip_url = next(
            (artifact['archive_download_url']
                for artifact in artifacts['artifacts']
                if artifact['name'] == 'Linux binary (debug)'),
            None
        )

        if zip_url is None:
            print("Could not find a Linux artifact for workflow run")
        else:
            sri_hash = nix_download(zip_url)

            broker_section = """\
# COMMIT: {oid}
portier-broker-testing = derivation (self.portier-broker.drvAttrs // {{
  name = "portier-broker-{shorthash}";

  testsrc = self.fetchurl {{
      url = "{zip_url}";
      hash = "{sri_hash}";
  }};

  inherit (self) unzip;

  builder = "${{self.bash}}/bin/bash";
  args = [ "-e" ./build-testing-broker.sh ];
}});
"""         .format(
                oid=broker_head['oid'],
                shorthash=broker_head['oid'][:7],
                zip_url=zip_url,
                sri_hash=sri_hash
            )

# If the commit hash appears in the existing section, we don't have to update.
# Otherwise, fetch the file so we can determine the hash, and add it to the
# store so we don't have to download it again.
demo_head = response['data']['demo']['defaultBranchRef']['target']
demo_section = extract_section(existing, "portier/demo-rp")
if demo_head['oid'] in demo_section:
    print("No change to portier/demo-rp")
else:
    print("Preparing deploy of portier/demo-rp " + demo_head['oid'])

    sri_hash = nix_download(demo_head['tarballUrl'])

    demo_section = """\
# COMMIT: {oid}
portier-demo-testing = derivation (self.portier-demo.drvAttrs // {{
  name = "portier-demo-{shorthash}";

  src = self.fetchurl {{
    url = "{tarball_url}";
    hash = "{sri_hash}";
  }};
}});
""" .format(
        oid=demo_head['oid'],
        shorthash=demo_head['oid'][:7],
        tarball_url=demo_head['tarballUrl'],
        sri_hash=sri_hash
    )

# Build the final output.
output = """\
let overlay = self: super: {{

{broker_section}\

{demo_section}\

}}; in {{ config.nixpkgs.overlays = [ overlay ]; }}
""".format(
    broker_section=make_section("portier/portier-broker", broker_section),
    demo_section=make_section("portier/demo-rp", demo_section)
)

# If there were changes, write the config file and rebuild the system.
if output != existing:
    with open(config_path, 'w') as f:
        f.write(output)
    os.execvp('nixos-rebuild',
              ['nixos-rebuild', 'switch', '--no-build-output'])
