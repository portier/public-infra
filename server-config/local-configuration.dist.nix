# This module tries to group all settings that are deemed server-local.
#
# The idea is that it should be possible to create a replica of the Portier
# server anywhere, and only these settings would have to be adjusted.

{ lib, pkgs, ... }:

let
  portier-broker-testing = if lib.hasAttr "portier-broker-testing" pkgs
    then pkgs.portier-broker-testing else pkgs.portier-broker;
  portier-demo-testing = if lib.hasAttr "portier-demo-testing" pkgs
    then pkgs.portier-demo-testing else pkgs.portier-demo;
in

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

  allowSshFrom = [
    # "1.2.3.4"
  ];

  adminAuthorizedKeys = [
    # "ssh-..."
  ];

  portier = {
    acmeEmail = "staff@portier.io";
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
        brokerPackage = portier-broker-testing;
        brokerPort = 20080;
        brokerVhost = "broker.staging.portier.io";
        demoPackage = portier-demo-testing;
        demoPort = 20081;
        demoVhost = "demo.staging.portier.io";
      };
    };
  };

  webhook.virtualHost = "server.portier.io";
}
