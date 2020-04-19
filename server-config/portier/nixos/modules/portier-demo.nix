{ config, lib, pkgs, ... }:

with lib;

let

  moduleOptions = serviceOptions // {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the Portier demo service.
      '';
    };
    instances = mkOption {
      type = with types; attrsOf (submodule {
        options = serviceOptions;
      });
      default = {};
      description = ''
        Definition of additional instances of the Portier demo.

        The attribute name in this set determines the name of the system user,
        the state directory in `/var/lib`, and the service name created. Note
        that if the regular service outside 'instances' is enabled, the name
        'portier-demo' is used and cannot appear in this set.
      '';
    };
  };

  serviceOptions = {
    package = mkOption {
      type = types.package;
      default = pkgs.portier-demo;
      defaultText = "pkgs.portier-demo";
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

in {

  options.services.portier-demo = moduleOptions;

  config = let
    cfg = config.services.portier-demo;
    instances = cfg.instances
      // optionalAttrs cfg.enable { "portier-broker" = cfg; };
    mapInstances = flip mapAttrs instances;
  in {

    users.users = mapInstances (name: inst: {
      isSystemUser = true;
      description = "Portier demo service";
    });

    systemd.services = mapInstances (name: inst: {
      description = "Portier demo";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        DEMO_LISTEN_IP = "127.0.0.1";
        DEMO_LISTEN_PORT = builtins.toString inst.port;
        DEMO_WEBSITE_URL = assert inst.websiteUrl != ""; inst.websiteUrl;
        DEMO_BROKER_URL = assert inst.brokerUrl != ""; inst.brokerUrl;
        DEMO_REDIS_URL = inst.redisUrl;
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      confinement = {
        enable = true;
        packages = [
          inst.package.python
          pkgs.cacert
        ];
      };
      serviceConfig = {
        ExecStart = "${inst.package}/bin/portier-demo";
        WorkingDirectory = inst.package;
        User = name;

        Restart = "always";
        RestartSec = 10;

        StateDirectory = name;
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
        SystemCallFilter = "@system-service";

        BindReadOnlyPaths = [ "/etc/resolv.conf" ];
      };
    });

  };

}
