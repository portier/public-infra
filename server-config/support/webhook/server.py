#!/usr/bin/env python3

"""Simple webhook server that performs deployments."""

import os
import requests
import subprocess
import sys
import threading
from flask import Flask
from github_webhook import Webhook

app = Flask("webhook")

with open("/private/webhook-secret.txt", "r") as f:
    webhook = Webhook(app, "/postreceive", f.read().strip())

with open("/private/github-token.txt", "r") as f:
    gh = requests.Session()
    gh.headers.update({
        "Authorization": "token " + f.read().strip(),
        "Accept": "application/vnd.github.v3+json",
    })

next_deployment = None
next_deployment_cv = threading.Condition()


def post_status(url, state, description=""):
    """Send a POST request to update deployment status."""

    res = gh.post(url, json={"state": state, "description": description})
    if res.status_code != 201:
        print(f"Could not set status: HTTP {res.status_code}", file=sys.stderr)


def deploy_loop():
    """Thread entry-point that runs a loop dispatching deployments."""

    global next_deployment
    global next_deployment_cv

    while True:
        with next_deployment_cv:
            while not next_deployment:
                next_deployment_cv.wait()
            statuses_url, target_system = next_deployment
            next_deployment = None

        try:
            do_deploy(statuses_url, target_system)
        except Exception as exc:
            print(exc, file=sys.stderr)
            post_status(statuses_url, "error")


def do_deploy(statuses_url, target_system):
    """Perform a deployment."""

    current_system = os.readlink("/run/current-system")
    if current_system == target_system:
        post_status(statuses_url, "success", "no change")
        return

    print(f"== Preparing: {target_system}", file=sys.stderr)
    post_status(statuses_url, "in_progress", "preparing")
    # Download the build.
    subprocess.run([
        "nix-store",
        "--realise", target_system,
        "--add-root", "/nix/var/nix/gcroots/webhook-build",
    ], check=True)

    with next_deployment_cv:
        if next_deployment:
            return

    print(f"== Activating: {target_system}", file=sys.stderr)
    post_status(statuses_url, "in_progress", "activating")
    # Update the 'system' profile.
    subprocess.run([
        "nix-env",
        "--profile", "/nix/var/nix/profiles/system",
        "--set", target_system,
    ], check=True)
    # Use systemd-run so if we are restarted, activation is not interrupted.
    subprocess.run([
        "systemd-run", "--quiet", "--wait", "--collect",
        "--unit=activate-deployment",
        "/nix/var/nix/profiles/system/bin/switch-to-configuration", "switch",
    ], check=True)

    post_status(statuses_url, "success")


@webhook.hook(event_type="deployment")
def on_deployment(data):
    """GitHub 'deployment' event handler."""

    global next_deployment
    global next_deployment_cv

    if data["action"] != "created":
        return

    statuses_url = data["deployment"]["statuses_url"]
    target_system = data["deployment"]["payload"]["store_path"]
    with next_deployment_cv:
        next_deployment = statuses_url, target_system
        next_deployment_cv.notify()


if __name__ == "__main__":
    threading.Thread(target=deploy_loop).start()
    app.run(host="127.0.0.1", port=29999)
