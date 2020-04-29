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

def nix_download(url):
    """Download a file to the Nix store, and return the SRI hash."""
    filename = basename(urlparse(url).path)
    with TemporaryDirectory() as tmpdir:
        filepath = "{}/{}".format(tmpdir, filename)
        with open(filepath, "wb") as tmpfile:
            with urlopen(url) as download:
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
    content = dedent(content).strip()
    start = "### Begin section: {}".format(name)
    end = "### End section: {}".format(name)
    return start + "\n" + content.strip() + "\n" + end + "\n"

def extract_section(text, name):
    """Extrat a section from multiline text."""
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
    token = f.read().strip()

# Query GitHub.
query = dedent("""\
{
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
""")
request = Request(
    'https://api.github.com/graphql',
    json.dumps({'query': query}).encode(),
    {
        'Authorization': 'Bearer {}'.format(token),
        'Content-Type': 'application/json'
    }
)
with urlopen(request) as f:
    if f.getcode() != 200:
        raise Exception("GitHub query failed: {}".format(f.getcode()))
    response = json.loads(f.read())

# If the demo-rp tarball URL appears in the existing config, we assume we don't
# have to update, because it includes the git hash. Otherwise, fetch the file
# so we can determine the hash, and add it to the store so we don't have to
# download it again.
demo_head = response['data']['demo']['defaultBranchRef']['target']
demo_section = extract_section(existing, "portier/demo-rp")
if not demo_head['tarballUrl'] in existing:
    print("Preparing deploy of portier/demo-rp {}".format(demo_head['oid']))
    sri_hash = nix_download(demo_head['tarballUrl'])
    demo_section = """\
    portier-demo-testing = super.portier-demo // {{
      src = super.fetchurl {{
        url = "{tarball_url}";
        hash = "{sri_hash}";
      }};
    }};
    """.format(
        tarball_url=demo_head['tarballUrl'],
        sri_hash=sri_hash
    )

# Build the final output.
output = dedent("""\
let overlay = self: super: {{

{demo_section}\

}}; in {{ config.nixpkgs.overlays = [ overlay ]; }}
""").format(
    demo_section=make_section("portier/demo-rp", demo_section)
)

# If there were changes, write the config file and rebuild the system.
if output != existing:
    with open(config_path, 'w') as f:
        f.write(output)
    os.execvp('nixos-rebuild', ['nixos-rebuild', 'switch', '--no-build-output'])
