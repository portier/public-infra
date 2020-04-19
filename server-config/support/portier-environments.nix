# NixOS module that holds common configuration and logic
# for setting up multiple Portier environments. Each
# environment contains a broker and a demo.

{ config, lib, ... }:

with lib;

let

  moduleOptions = {
    acmeEmail = mkOption {
      type = types.str;
      default = "";
      description = ''
        Email address to use for ACME registrations.
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
    environments = mkOption {
      type = with types; attrsOf (submodule {
        options = environmentOptions;
      });
      default = {};
      description = ''
        Definition of Portier environments.

        Each attribute defined in this set creates an instance of the broker
        named 'portier-broker-{attr}', an instance the demo application named
        'portier-demo-{attr}', and Nginx virtual hosts with HTTPS enabled using
        ACME.
      '';
    };
  };

  environmentOptions = {
    brokerPort = mkOption {
      type = types.port;
      default = 3333;
      description = ''
        Specifies on which port the Portier broker listens.
      '';
    };
    demoPort = mkOption {
      type = types.port;
      default = 8000;
      description = ''
        Specifies on which port the Portier demo listens.
      '';
    };
    brokerVhost = mkOption {
      type = types.str;
      default = "";
      description = ''
        The virtual host of the Portier broker.
      '';
    };
    demoVhost = mkOption {
      type = types.str;
      default = "";
      description = ''
        The virtual host of the Portier demo.
      '';
    };
  };

in {

  imports = [ ../portier/nixos ];

  options.portier = moduleOptions;

  config = let
    cfg = config.portier;
    mergeMapEnvs = f: mkMerge (mapAttrsToList f cfg.environments);
  in {

    services.portier-broker.instances = mergeMapEnvs (name: env: {
      "portier-broker-${name}" = {
        port = env.brokerPort;
        publicUrl = "https://${env.brokerVhost}";
        fromName = cfg.fromName;
        fromAddress = cfg.fromAddress;
        smtpServer = cfg.smtpServer;
        googleClientId = cfg.googleClientId;
        configFile = cfg.configFile;
      };
    });

    services.portier-demo.instances = mergeMapEnvs (name: env: {
      "portier-demo-${name}" = {
        port = env.demoPort;
        websiteUrl = "https://${env.demoVhost}";
        brokerUrl = "https://${env.brokerVhost}";
      };
    });

    services.nginx.virtualHosts = mergeMapEnvs (name: env: {
      "${env.brokerVhost}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString env.brokerPort}";
      };
      "${env.demoVhost}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString env.demoPort}";
      };
    });

    security.acme.certs = mergeMapEnvs (name: env: {
      "${env.brokerVhost}" = {
        email = cfg.acmeEmail;
      };
      "${env.demoVhost}" = {
        email = cfg.acmeEmail;
      };
    });

    # This allows making the config file readable for all environments.
    users.groups.portier = mergeMapEnvs (name: env: {
      members = [ "portier-broker-${name}" ];
    });

  };

}
