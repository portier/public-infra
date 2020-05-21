{ lib, config, pkgs, ... }:

with lib;

let

  socketPath = "/run/autotest-server.sock";
  secretFile = "/private/autotest-secret.txt";

  pythonPackages = pkgs: with pkgs; [ pyjwt cryptography ];
  python = pkgs.python38.withPackages pythonPackages;

  server = pkgs.rustPlatform.buildRustPackage {
    name = "autotest-server";
    src = ./server;
    cargoSha256 = "0yc932p6mj4l9i9qqkn8pgq2p6wpz0hch606vagb9a1c4h36ilcx";
    doCheck = false;
  };

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
        Name of an existing Nginx virtual host to add the `/autotest` location to.
      '';
    };
    testEmail = mkOption {
      type = types.str;
      default = "";
      description = ''
        Email address to try to authenticate with. Should be setup with
        Postmark to deliver to `/autotest`.
      '';
    };
  };

  config = {

    users.users.autotest = {
      isSystemUser = true;
      description = "Autotest service";
    };

    systemd.services.autotest-script = {
      description = "Autotest script";

      restartIfChanged = false;

      environment = with config.autotest; {
        BROKER_ORIGIN = brokerOrigin;
        TEST_ORIGIN = "https://${virtualHost}";
        TEST_EMAIL = testEmail;
        SECRET_FILE = secretFile;
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${python}/bin/python ${./script.py}";

        LogsDirectory="autotest";

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
        SystemCallFilter = "@system-service";

        BindReadOnlyPaths = [
          "/etc/resolv.conf"
          secretFile
        ];
      };
    };

    systemd.sockets.autotest-server = {
      description = "Autotest server";
      wantedBy = [ "sockets.target" ];
      listenStreams = [ socketPath ];
    };

    systemd.services.autotest-server = {
      description = "Autotest server";

      wantedBy = [ "multi-user.target" ];
      requires = [ "autotest-server.socket" ];
      after = [ "autotest-server.socket" "network.target" ];

      environment = {
        SECRET_FILE = secretFile;
      };

      confinement = {
        enable = true;
      };

      serviceConfig = {
        ExecStart = "${server}/bin/autotest-server";
        User = "autotest";

        Restart = "always";
        RestartSec = 10;

        CapabilityBoundingSet = "";
        IPAddressDeny = "any";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateNetwork = true;
        ProtectHome = true;
        ProtectHostname = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_UNIX" "~AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [ "@system-service" "~@privileged @resources" ];

        BindReadOnlyPaths = [ secretFile ];
      };
    };

    services.nginx.virtualHosts = {
      "${config.autotest.virtualHost}" = {
        locations."/autotest".proxyPass = "http://unix:${socketPath}";
      };
    };

  };
}
