{ config, lib, pkgs, flakeInputs, ... }:

with lib;

let

  # We maintain the module for testing as a copy of production, so we can
  # easily test module changes. This variable defines the basename of options
  # for this module. Using a variable allows easier diffing.
  moduleName = "portier-broker-testing";

  cfg = config.services.${moduleName};

in {

  options.services.${moduleName} = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable the Portier broker service.
      '';
    };
    package = mkOption {
      type = types.package;
      default = flakeInputs.${moduleName}.packages.${pkgs.system}.default;
      defaultText = "flakeInput.${moduleName}.packages.${pkgs.system}.default";
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
      type = with types; nullOr str;
      default = null;
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
    verifyWithResolver = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Optional DNS resolver to use to verify email domains.
      '';
    };
    verifyPublicIp = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether the email domain must have a mail server with a public IP.
        Requires verifyWithResolver to be set.
      '';
    };
    configFile = mkOption {
      type = types.str;
      default = "";
      description = ''
        Optional configuration file for the broker.

        Use this file to store secrets that shouldn't end up in the Nix store,
        such as SMTP credentials or private keys, if you need them. Make sure
        the file is readable only by the ${moduleName} user!
      '';
    };
  };

  config = {

    users = mkIf cfg.enable {
      groups.${moduleName} = { };
      users.${moduleName} = {
        isSystemUser = true;
        group = moduleName;
        description = "Portier broker service";
      };
    };

    systemd.services.${moduleName} = mkIf cfg.enable {
      description = "Portier broker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        BROKER_SQLITE_DB = "/var/lib/${moduleName}/db.sqlite3";
        BROKER_LISTEN_IP = "127.0.0.1";
        BROKER_LISTEN_PORT = builtins.toString cfg.port;
        BROKER_PUBLIC_URL = assert cfg.publicUrl != ""; cfg.publicUrl;
        BROKER_ALLOWED_ORIGINS =
          if cfg.allowedOrigins != null
          then builtins.toString cfg.allowedOrigins
          else null;
        BROKER_FROM_NAME = assert cfg.fromName != null; cfg.fromName;
        BROKER_FROM_ADDRESS = assert cfg.fromAddress != null; cfg.fromAddress;
        BROKER_SMTP_SERVER = cfg.smtpServer;
        BROKER_GOOGLE_CLIENT_ID = cfg.googleClientId;
        BROKER_VERIFY_WITH_RESOLVER = cfg.verifyWithResolver;
        BROKER_VERIFY_PUBLIC_IP = mkIf cfg.verifyPublicIp "true";
        BROKER_UNCOUNTED_EMAILS = "autotest@server.portier.io";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/portier-broker"
          + optionalString (cfg.configFile != "") " /__portier/config.toml";
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

        BindReadOnlyPaths = optional (cfg.configFile != "") "${cfg.configFile}:/__portier/config.toml";
      };
    };

  };

}
