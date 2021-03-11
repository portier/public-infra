#!/usr/bin/env python38

"""
Fetches the latest testing versions, then rebuilds the system.
"""

import json
import os
from shutil import copyfileobj
from tempfile import TemporaryDirectory
from time import sleep
from urllib.request import Request, urlopen


downloads_path = "/etc/nixos/support/portier-testing/downloads"


def call_github(resource, body=None):
    """Make a request to the GitHub API."""
    url = f"https://api.github.com{resource}"
    data = None
    headers = dict(request_headers)
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    with urlopen(Request(url, data, headers)) as f:
        return json.loads(f.read())


def download_file(filename, url):
    """Download a GitHub file and place it in the downloads directory."""
    with TemporaryDirectory() as tmpdir:
        filepath = f"{tmpdir}/{filename}"
        with open(filepath, "wb") as tmpfile:
            with urlopen(Request(url, None, request_headers)) as download:
                copyfileobj(download, tmpfile)
        os.rename(filepath, f"{downloads_path}/{filename}")


def check_oid(statefile, oid):
    """Check if the git hash has changed, based on a state file."""
    statepath = f"{downloads_path}/{statefile}"
    try:
        with open(statepath, "r") as f:
            return f.read() == oid
    except FileNotFoundError:
        return False


def write_oid(statefile, oid):
    """Write a state file containing the latest git hash."""
    statepath = f"{downloads_path}/{statefile}"
    with open(statepath, "w") as f:
        f.write(oid)


# Default GitHub request headers.
with open("/private/github-token.txt", "r") as f:
    request_headers = {
        "User-Agent": "portier webhook",
        "Authorization": "Bearer " + f.read().strip(),
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
response = call_github("/graphql", {"query": query})

has_changes = False

# If the commit hash appears in the existing section, we don't have to update.
# Otherwise, fetch the latest build artifact so we can determine the hash, and
# add it to the store so we don't have to download it again.
broker_head = response["data"]["broker"]["defaultBranchRef"]["target"]
if check_oid("portier-broker-oid.txt", broker_head["oid"]):
    print("No change to portier/portier-broker")
else:
    print("Downloading new portier/portier-broker " + broker_head["oid"])

    run_id = None
    in_progress = True
    is_success = False
    while in_progress:
        # We assume this returns the most recent runs first.
        runs_resource = (
            "/repos/portier/portier-broker/actions/workflows/build.yml/runs"
            + "?branch=master&per_page=5"
        )
        runs = call_github(runs_resource)

        run_id = None
        in_progress = False
        is_success = False
        for run in runs["workflow_runs"]:
            if run["head_sha"] == broker_head["oid"]:
                run_id = run["id"]
                in_progress = run["status"] == "in_progress"
                is_success = run["conclusion"] == "success"
                break

        # Delay between requests.
        sleep(10)

    if run_id is None:
        print("Could not find the workflow run for this commit")
    elif not is_success:
        print("Workflow run was not successful, skipping deploy")
    else:
        artifacts_resource = (
            f"/repos/portier/portier-broker/actions/runs/{run_id}/artifacts"
        )
        artifacts = call_github(artifacts_resource)
        zip_url = next(
            (
                artifact["archive_download_url"]
                for artifact in artifacts["artifacts"]
                if artifact["name"] == "Linux binary (debug)"
            ),
            None,
        )

        if zip_url is None:
            print("Could not find a Linux artifact for workflow run")
        else:
            download_file("portier-broker-testing.zip", zip_url)
            write_oid("portier-broker-oid.txt", broker_head["oid"])
            has_changes = True

# If the commit hash appears in the existing section, we don't have to update.
# Otherwise, fetch the file so we can determine the hash, and add it to the
# store so we don't have to download it again.
demo_head = response["data"]["demo"]["defaultBranchRef"]["target"]
if check_oid("portier-demo-oid.txt", demo_head["oid"]):
    print("No change to portier/demo-rp")
else:
    print("Downloading new portier/demo-rp " + demo_head["oid"])
    download_file("portier-demo-testing.tar.gz", demo_head["tarballUrl"])
    write_oid("portier-demo-oid.txt", demo_head["oid"])
    has_changes = True

# Apply changes.
if has_changes:
    os.execvp(
        "nixos-rebuild", ["nixos-rebuild", "switch", "--no-build-output"]
    )
