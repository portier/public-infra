# Portier project server configuration

This directory contains the [NixOS](https://nixos.org) configuration for the
server run by the Portier project.

We use NixOS for several reasons:

- The entire server configuration can be documented publically. This helps us
  build trust in our public broker, which is important for a security
  component like Portier.

- Mutable state on the server is minimized. This benefits the above point
  about documentation and trust, but also means less surprises for admins.

- NixOS has excellent sandboxing capabilities, which is important for a
  security component like Portier.

Note that the configuration here may not be out-of-the-box suitable to apply to
your own server, but we do try to isolate installation-specific details in
`local-configuration.nix`.

We run our server on [Hetzner Cloud](https://www.hetzner.com/cloud) on a CX11
instance (smallest configuration) in the Nuremberg data center.

The procedure for setting up this server is:

- Create the CX11 instance from the Hetzner Cloud console. Use any OS image for
  now, and leave the volume and network sections empty, but set a (temporary)
  SSH key-pair if you want. Also give it a descriptive name. (We prefer using
  the fully-qualified hostname.)

- Update `local-configuration.nix` in the git repository, but don't commit or
  push these changes yet.

  You may need to log in to the server and take note of some settings generated
  by Hetzner, such as the IPv6 configuration.

- Update DNS records for the broker and demo to point to the new server IPs.

- In the Hetzner Cloud console, go to 'ISO Images' and mount NixOS.

- Go to 'Power' and perform a power cycle.

- Open the server console. The NixOS installer should have booted into a
  shell.

- Use the server console to follow the regular NixOS installation steps. These
  are the commands from the manual summary near exactly:
  https://nixos.org/nixos/manual/index.html#sec-installation-summary

  - When partitioning the disk, use MBR instead of GPT. Instead of the 8 GiB
    swap in the manual examples, use 2 GiB (of the 20 GiB disk).

  - Set the following options in `/etc/nixos/configuration.nix`:

    ```
    boot.loader.grub.device = "/dev/sda";
    services.openssh.enable = true;
    services.openssh.permitRootLogin = "yes";
    nix.binaryCaches = [ "https://portier.cachix.org" ];
    nix.binaryCachePublicKeys = [ "portier.cachix.org-1:thI6UJMG/LFzmEGS8LExOlwwjSWvqsSeb/skVOCFbds=" ];
    ```

  - `nixos-install` will ask you to set a root password. This is a temporary
    password which will be unset by the end of these steps.

  - Instead of `reboot`, do `poweroff`.

- Once powered off, use the Hetzner Cloud console to unmount the NixOS
  installer ISO. Then start the server again.

- Check that you can SSH into the server as `root`, with the password you
  entered during `nixos-install`.

- Update `hardware-configuration.nix` in the git repository from the server
  copy.

- Commit and push changes in the git repository to start a build on GitHub.

- Create a directory for credentials with `mkdir -m 0700 /private`. Only the
  directory itself needs to have these permissions, not the files within. We
  deliberately keep the contents outside the repository AND outside the
  world-readable Nix store.

- Create `/private/portier-mailer.toml` containing just the mailer settings.
  For us, this is only `postmark_token`.

- Create `/private/github-token.txt` containing just a GitHub personal access
  token. This token should have the `repo` scope in order to download artifacts
  and update deployment statuses.

- Create `/private/webhook-secret.txt` containing a random secret (something
  like `pwgen -s 64`) used to protect the webhook calls for continuous
  deployment.

- Configure a webhook on this GitHub repository:
  https://github.com/portier/public-infra/settings/hooks

  Only the `deployment` event is used. Set the URL to `/webhook` on the webhook
  virtual host you configured in `local-configuration.nix`. Use the secret from
  `/private/webhook-secret.txt`.

- Find the latest build on GitHub Actions:
  https://github.com/portier/public-infra/actions/workflows/build.yml

  In the 'Build' step, the very last line should contain a Nix store path like
  `/nix/store/*-nixos-system-public-portier-*`.

- Download the build on the server:
  `nix-store --realise <path>`

- Set the system profile:
  `nix-env --profile /nix/var/nix/profiles/system --set <path>`

- Prepare the build for next boot:
  `/nix/var/nix/profiles/system/bin/switch-to-configuration boot`

- Reboot the server.

- Check that you can now login using your SSH key-pair as the `admin` user.

- Check that all services are working properly.

The webhook will now autodeploy builds from this repository.
