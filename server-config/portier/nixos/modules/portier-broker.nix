{ config, lib, pkgs, ... }:

with lib;

let

  moduleOptions = serviceOptions // {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the Portier broker service.
      '';
    };
    instances = mkOption {
      type = with types; attrsOf (submodule {
        options = serviceOptions;
      });
      default = {};
      description = ''
        Definition of additional instances of the Portier broker.

        The attribute name in this set determines the name of the system user,
        the state directory in `/var/lib`, and the service name created. Note
        that if the regular service outside 'instances' is enabled, the name
        'portier-broker' is used and cannot appear in this set.
      '';
    };
  };

  serviceOptions = {
    package = mkOption {
      type = types.package;
      default = pkgs.portier-broker;
      defaultText = "pkgs.portier-broker";
      description = ''
        The Portier broker package to use.
      '';
    };
    port = mkOption {
      type = types.port;
      default = 3333;
      description = ''
        Specifies on which port the Portier broker listens.

        The broker will currently always listen on IPv4 localhost only.
      '';
    };
    publicUrl = mkOption {
      type = types.str;
      default = "";
      description = ''
        The broker server's public-facing URL. (Required)

        It's important to set this correctly, or JSON Web Tokens will fail to
        validate. Relying Parties will use the same value for their broker URL. To
        ensure consistency, trailing slashes should be avoided.
      '';
    };
    allowedOrigins = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
      description = ''
        Whitelist of origins that are allowed to use this broker. If left unset, the
        broker will allow any Relying Party to use it. (Note that an empty list here
        has different meaning than leaving it unset.)
      '';
    };
    fromName = mkOption {
      type = types.str;
      default = "Portier";
      description = ''
        The 'From' name used by Portier to send emails.
      '';
    };
    fromAddress = mkOption {
      type = types.str;
      default = "";
      description = ''
        The 'From' address used by Portier to send emails. (Required)
      '';
    };
    smtpServer = mkOption {
      type = types.str;
      default = "";
      description = ''
        Hostname of the SMTP server used to send mails. (Required)
      '';
    };
    googleClientId = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Optional Google Client ID for verifying `@gmail.com` addresses.
        You can create one of these at: https://console.cloud.google.com/
      '';
    };
    configFile = mkOption {
      type = types.str;
      default = "";
      description = ''
        Optional configuration file for the broker.

        Use this file to store secrets that shouldn't end up in the Nix store,
        such as SMTP credentials or private keys, if you need them. Make sure
        the file is readable only by the portier-broker user!
      '';
    };
  };

in {

  options.services.portier-broker = moduleOptions;

  config = let
    cfg = config.services.portier-broker;
    instances = cfg.instances
      // optionalAttrs cfg.enable { "portier-broker" = cfg; };
    mapInstances = flip mapAttrs instances;
  in {

    users.users = mapInstances (name: inst: {
      isSystemUser = true;
      description = "Portier broker service";
    });

    systemd.services = mapInstances (name: inst: {
      description = "Portier broker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        BROKER_GENERATE_RSA_COMMAND = "${pkgs.openssl}/bin/openssl genrsa 2048";
        BROKER_SQLITE_DB = "/var/lib/${name}/db.sqlite3";
        BROKER_LISTEN_IP = "127.0.0.1";
        BROKER_LISTEN_PORT = builtins.toString inst.port;
        BROKER_PUBLIC_URL = assert inst.publicUrl != ""; inst.publicUrl;
        BROKER_ALLOWED_ORIGINS =
          if inst.allowedOrigins != null
          then builtins.toString inst.allowedOrigins
          else null;
        BROKER_FROM_NAME = assert inst.fromName != null; inst.fromName;
        BROKER_FROM_ADDRESS = assert inst.fromAddress != null; inst.fromAddress;
        BROKER_SMTP_SERVER = assert inst.smtpServer != null; inst.smtpServer;
        BROKER_GOOGLE_CLIENT_ID = inst.googleClientId;
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      confinement = {
        enable = true;
        packages = [
          pkgs.openssl
          pkgs.cacert
        ];
        binSh = null;
      };
      serviceConfig = {
        ExecStart = "${inst.package}/portier-broker ${inst.configFile}";
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

        BindReadOnlyPaths = [ "/etc/resolv.conf" ]
          ++ optional (inst.configFile != "") inst.configFile;
      };
    });

  };

}
