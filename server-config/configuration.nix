# Main configuration file.
#
# This configures various system settings and imports other modules to do most
# of the actual configuration.

{ pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/profiles/hardened.nix>
    <nixpkgs/nixos/modules/profiles/headless.nix>
    <nixpkgs/nixos/modules/profiles/minimal.nix>
    ./hardware-configuration.nix
    ./local-configuration.nix
    ./portier/nixos
    ./support/security
    ./support/default-vhost
    ./support/webhook
    ./support/autotest
    ./support/portier-environments
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };

  nix = {
    daemonNiceLevel = 5;
    daemonIONiceLevel = 5;
  };
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };

  boot.loader.timeout = 3;
  boot.enableContainers = false;
  appstream.enable = false;
  security.allowUserNamespaces = true;

  networking.useDHCP = false;

  environment.systemPackages = with pkgs; [
    vim
  ];

  security.acme.acceptTerms = true;

  services.chrony.enable = true;

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
}
