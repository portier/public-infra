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
from textwrap import dedent
from urllib.parse import urlparse
from urllib.request import Request, urlopen

# Default GitHub request headers.
# The authentication token is added to this below.
request_headers = {
    'User-Agent': 'portier webhook'
}

def call_github(resource, body=None):
    """Make a request to the GitHub API."""
    url = 'https://api.github.com{}'.format(resource)
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
        filepath = "{}/{}".format(tmpdir, filename)
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
    return "sha256-{}".format(b64encode(hasher.digest()).decode())

def make_section(name, content):
    """Format a section containing multiline text."""
    start = "### Begin section: {}".format(name)
    end = "### End section: {}".format(name)
    return start + "\n" + content.strip() + "\n" + end + "\n"

def extract_section(text, name):
    """Extract a section from multiline text."""
    lines = text.splitlines()
    try:
        start = lines.index('### Begin section: {}'.format(name))
        end = lines.index('### End section: {}'.format(name), start + 1)
        return "\n".join(lines[start+1:end])
    except ValueError:
        return ""

# Read the existing config.
config_path = '/etc/nixos/support/webhook/generated.nix'
try:
    with open(config_path, 'r') as f:
        existing = f.read()
except FileNotFoundError:
    existing = ''

# Grab the GitHub token.
with open('/private/github-token.txt', 'r') as f:
    request_headers['Authorization'] = 'Bearer {}'.format(f.read().strip())

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
if not broker_head['oid'] in broker_section:
    print("Preparing deploy of portier/portier-broker {}".format(broker_head['oid']))

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
            '/repos/portier/portier-broker/actions/runs/{}/artifacts'.format(run_id)
        )
        artifacts = call_github(artifacts_resource)
        zip_url = next(
            (artifact['archive_download_url'] for artifact in artifacts['artifacts']
                if artifact['name'] == 'Linux binary (debug)'),
            None
        )

        if zip_url is None:
            print("Could not find a Linux artifact for workflow run")
        else:
            sri_hash = nix_download(zip_url)

            broker_section = dedent("""\
            # COMMIT: {oid}
            portier-broker-testing = derivation (self.portier-broker.drvAttrs // {{
              name = "portier-broker-testing";

              testsrc = self.fetchurl {{
                  url = "{zip_url}";
                  hash = "{sri_hash}";
              }};

              inherit (self) unzip;

              builder = "${{self.bash}}/bin/bash";
              args = [ "-e" ./build-testing-broker.sh ];
            }});
            """).format(
                oid=broker_head['oid'],
                zip_url=zip_url,
                sri_hash=sri_hash
            )

# If the commit hash appears in the existing section, we don't have to update.
# Otherwise, fetch the file so we can determine the hash, and add it to the
# store so we don't have to download it again.
demo_head = response['data']['demo']['defaultBranchRef']['target']
demo_section = extract_section(existing, "portier/demo-rp")
if not demo_head['oid'] in demo_section:
    print("Preparing deploy of portier/demo-rp {}".format(demo_head['oid']))

    sri_hash = nix_download(demo_head['tarballUrl'])

    demo_section = dedent("""\
    # COMMIT: {oid}
    portier-demo-testing = derivation (self.portier-demo.drvAttrs // {{
      name = "portier-demo-testing";

      src = self.fetchurl {{
        url = "{tarball_url}";
        hash = "{sri_hash}";
      }};
    }});
    """).format(
        oid=demo_head['oid'],
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
    os.execvp('nixos-rebuild', ['nixos-rebuild', 'switch', '--no-build-output'])
