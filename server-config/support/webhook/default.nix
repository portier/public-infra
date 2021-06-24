{ lib, config, pkgs, ... }:

with lib;

let

  nix = config.nix.package.out;

  python = pkgs.python39.withPackages (pkgs: with pkgs; [
    flask github-webhook requests
  ]);

  server = pkgs.runCommandLocal "webhook-server.py" {
    buildInputs = [ python pkgs.python39Packages.flake8 ];
  } ''
    cp '${./server.py}' $out
    flake8 --show-source $out
    patchShebangs $out
  '';

in {

  options.webhook = {
    virtualHost = mkOption {
      type = types.str;
      default = "";
      description = ''
        Name of an existing Nginx virtual host to add the /webhook location to.
      '';
    };
  };

  config = {

    systemd.services.webhook-server = {
      description = "Webhook server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [nix];
      serviceConfig = {
        ExecStart = server;
        Restart = "always";
        RestartSec = 10;
      };
    };

    services.nginx.virtualHosts = {
      "${config.webhook.virtualHost}" = {
        locations."= /webhook".proxyPass = "http://127.0.0.1:29999/postreceive";
      };
    };

  };
}
