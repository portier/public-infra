{ lib, config, pkgs, ... }:

with lib;

let

  python = pkgs.python3.withPackages (pkgs: with pkgs; [
    pyjwt cryptography
  ]);

  script = pkgs.runCommandLocal "autotest-script.py" {
    buildInputs = [ python pkgs.python3Packages.flake8 ];
  } ''
    cp '${./script.py}' $out
    flake8 --show-source $out
    patchShebangs $out
  '';

in {

  options.autotest = {
    brokerOrigin = mkOption {
      type = types.str;
      default = "";
      description = ''
        Origin of the broker to test.
      '';
    };
    virtualHost = mkOption {
      type = types.str;
      default = "";
      description = ''
        Name of the Nginx virtual host to use. Will set the root for `/`.
      '';
    };
  };

  config = {

    users = {
      groups.autotest = { };
      users.autotest = {
        isSystemUser = true;
        group = "autotest";
        description = "Autotest";
      };
    };

    systemd.services.autotest = {
      description = "Autotest";

      startAt = "*:0/5";
      restartIfChanged = false;

      environment = with config.autotest; {
        BROKER_ORIGIN = brokerOrigin;
        TEST_HOST = virtualHost;
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };

      confinement = {
        enable = true;
        packages = [ pkgs.cacert ];
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
        User = "autotest";

        StateDirectory = "autotest";
        LogsDirectory = "autotest";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectHostname = true;
        RemoveIPC = true;
        RestrictAddressFamilies = "AF_INET AF_INET6";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [ "@system-service" "~@privileged @resources" ];

        BindReadOnlyPaths = [ "/etc/resolv.conf" ];
      };
    };

    services.nginx.virtualHosts = {
      "${config.autotest.virtualHost}" = {
        locations."/".root = "/var/lib/autotest/public";
      };
    };

  };
}
