{ lib, config, pkgs, ... }:

with lib;

let

  python = pkgs.python38;
  nix = config.nix.package.out;
  nixos-rebuild = config.system.build.nixos-rebuild;

  server = pkgs.rustPlatform.buildRustPackage {
    name = "webhook-server";
    src = ./server;
    cargoSha256 = "0yc932p6mj4l9i9qqkn8pgq2p6wpz0hch606vagb9a1c4h36ilcx";
    doCheck = false;
  };

  # Because we reconfigure the system from our script, it may try to stop the
  # webhook server and thus itself. As a workaround, wrap it in a service.
  script-wrapper = pkgs.writeTextFile {
    name = "webhook-script-wrapper";
    executable = true;
    text = ''
      #!/bin/sh -e
      exec ${pkgs.systemd}/bin/systemctl start webhook-script --wait
    '';
  };


in {

  imports = optional (builtins.pathExists ./generated.nix) ./generated.nix;

  options.webhook = {
    virtualHost = mkOption {
      type = types.str;
      default = "";
      description = ''
        Nginx virtual host used to serve the webhook.
      '';
    };
  };

  config = {

    # This service is modelled after the NixOS auto-upgrade service.
    systemd.services.webhook-script = {
      description = "Webhook script";

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      environment = config.nix.envVars //
        { inherit (config.environment.sessionVariables) NIX_PATH;
          HOME = "/root";
        } // config.networking.proxy.envVars;

      path = with pkgs; [
        config.system.build.nixos-rebuild
        config.nix.package.out
        coreutils gnutar xz.bin gzip gitMinimal
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${python}/bin/python ${./script.py}";
      };
    };

    systemd.services.webhook-server = {
      description = "Webhook server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        LISTEN_ADDR = "127.0.0.1:29999";
        SECRET_FILE = "/private/webhook-secret.txt";
        COMMAND = script-wrapper;
      };
      serviceConfig = {
        ExecStart = "${server}/bin/webhook-server";
        Restart = "always";
        RestartSec = 10;
      };
    };

    services.nginx.virtualHosts = {
      "${config.webhook.virtualHost}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:29999";
      };
    };

    security.acme.certs = {
      "${config.webhook.virtualHost}" = {
        email = config.portier.acmeEmail;
      };
    };

  };
}
