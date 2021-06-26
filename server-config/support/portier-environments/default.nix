# NixOS module that ties together all the configuration for our Portier
# installations. This is here mostly as a layer for common settings, and to add
# nginx virtual hosts.

{ lib, ... }:

with lib;

let

  moduleOptions = {
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
    production = environmentOptions;
    testing = environmentOptions;
  };

  environmentOptions = {
    broker.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable the Portier broker service.
      '';
    };
    broker.vhost = mkOption {
      type = types.str;
      default = "";
      description = ''
        The virtual host of the Portier broker.
      '';
    };
    demo.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable the Portier demo service.
      '';
    };
    demo.vhost = mkOption {
      type = types.str;
      default = "";
      description = ''
        The virtual host of the Portier demo.
      '';
    };
  };

in {

  imports = [
    ./production.nix
    ./testing.nix
  ];

  options.portier = moduleOptions;

}
