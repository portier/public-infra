{ config, lib, pkgs, ... }:

with lib;

let

  # We maintain the module for testing as a copy of production, so we can
  # easily test module changes. This variable defines the basename of options
  # for this module. Using a variable allows easier diffing.
  moduleName = "portier-demo-testing";

  cfg = config.services.${moduleName};

in {

  options.services.${moduleName} = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable the Portier demo service.
      '';
    };
    package = mkOption {
      type = types.package;
      default = pkgs.${moduleName};
      defaultText = "pkgs.${moduleName}";
      description = ''
        The Portier demo package to use.
      '';
    };
    port = mkOption {
      type = types.port;
      default = 8000;
      description = ''
        Specifies on which port the Portier demo listens.

        The broker will currently always listen on IPv4 localhost only.
      '';
    };
    websiteUrl = mkOption {
      type = types.str;
      default = "";
      description = ''
        The demo server's public-facing URL. (Required)

        It's important to set this correctly, or redirects will fail and JSON
        Web Tokens will fail to validate. To ensure consistency, trailing
        slashes should be avoided.
      '';
    };
    brokerUrl = mkOption {
      type = types.str;
      default = "https://broker.portier.io";
      description = ''
        URL of the Portier broker to use for authentication.

        To ensure consistency, trailing slashes should be avoided.
      '';
    };
    redisUrl = mkOption {
      type = types.str;
      default = "";
      description = ''
        Optional URL of the Redis server to use.

        If not specified, will store sessions in-memory. This means sessions
        are lost when the service is restarted.
      '';
    };
  };

  config = {

    users = mkIf cfg.enable {
      groups.${moduleName} = { };
      users.${moduleName} = {
        isSystemUser = true;
        group = moduleName;
        description = "Portier demo service";
      };
    };

    systemd.services.${moduleName} = mkIf cfg.enable {
      description = "Portier demo";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        DEMO_LISTEN_IP = "127.0.0.1";
        DEMO_LISTEN_PORT = builtins.toString cfg.port;
        DEMO_WEBSITE_URL = assert cfg.websiteUrl != ""; cfg.websiteUrl;
        DEMO_BROKER_URL = assert cfg.brokerUrl != ""; cfg.brokerUrl;
        DEMO_REDIS_URL = cfg.redisUrl;
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      confinement = {
        enable = true;
        packages = [
          cfg.package.python
          pkgs.cacert
        ];
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/server.py";
        WorkingDirectory = cfg.package;
        User = moduleName;

        Restart = "always";
        RestartSec = 10;

        StateDirectory = moduleName;
        StateDirectoryMode = "0700";

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

  };

}
