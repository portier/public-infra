# This module tries to group all settings that are deemed server-local.
#
# The idea is that it should be possible to create a replica of the Portier
# server anywhere, and only these settings would have to be adjusted.

{ ... }:

{
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  time.timeZone = "UTC";

  networking.hostName = "server.portier.io";
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };
  networking.interfaces.ens3 = {
    useDHCP = true;
    ipv6.addresses = [
      { address = "1:2:3:4::1"; prefixLength = 64; }
    ];
  };

  system.stateVersion = "20.03";

  portier = {
    acmeEmail = "staff@portier.io";
    fromAddress = "noreply@portier.io";
    smtpServer = "smtp.postmarkapp.com:25";
    configFile = "/etc/portier-broker/smtp-credentials.toml";
    googleClientId = "288585393400-kbd02r4i35sfan68vri9sufkvkq87vt4.apps.googleusercontent.com";
    environments = {
      staging = {
        brokerPort = 20080;
        demoPort = 20081;
        brokerVhost = "broker.staging.portier.io";
        demoVhost = "demo.staging.portier.io";
      };
    };
  };
}
