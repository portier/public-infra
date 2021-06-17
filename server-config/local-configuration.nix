# This module tries to group all settings that are deemed server-local.
#
# The idea is that it should be possible to create a replica of the Portier
# server anywhere, and only these settings would have to be adjusted.

{ pkgs, ... }: {
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  time.timeZone = "UTC";

  networking.hostName = "public-portier";
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };
  networking.interfaces.ens3 = {
    useDHCP = true;
    ipv6.addresses = [
      { address = "2a01:4f8:c0c:c91c::1"; prefixLength = 64; }
    ];
  };

  # Should be the initial NixOS version the server was installed from.
  system.stateVersion = "20.03";

  adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXVHXBJXAb9rODD5ezABZQcshgsWiveJznbUeloFD9G stephank"
  ];

  # Misc vhost used for the webhook and autotest.
  services.nginx.virtualHosts = {
    "server.portier.io" = {
      enableACME = true;
      forceSSL = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    email = "staff@portier.io";
  };

  webhook = {
    virtualHost = "server.portier.io";
  };

  autotest = {
    brokerOrigin = "https://broker.portier.io";
    virtualHost = "server.portier.io";
  };

  prometheus = {
    virtualHost = "prometheus.portier.io";
  };

  portier = {
    fromAddress = "noreply@portier.io";
    configFile = "/private/portier-mailer.toml";
    googleClientId = "288585393400-kbd02r4i35sfan68vri9sufkvkq87vt4.apps.googleusercontent.com";
    environments = {
      production = {
        brokerPort = 30080;
        brokerVhost = "broker.portier.io";
        demoPort = 30081;
        demoVhost = "demo.portier.io";
      };
      staging = {
        brokerPackage = pkgs.portier-broker-testing;
        brokerPort = 20080;
        brokerVhost = "broker.staging.portier.io";
        demoPackage = pkgs.portier-demo-testing;
        demoPort = 20081;
        demoVhost = "demo.staging.portier.io";
      };
    };
  };
}
