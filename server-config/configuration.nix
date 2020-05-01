# Main configuration file.
#
# This configures various system settings and imports other modules to do most
# of the actual configuration.

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./local-configuration.nix
    ./portier/nixos
    ./support/security
    ./support/default-vhost
    ./support/webhook
    ./support/portier-environments
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };
  nix.gc.automatic = true;

  boot.loader.timeout = 3;
  boot.enableContainers = false;
  appstream.enable = false;
  documentation.enable = false;

  networking.useDHCP = false;

  environment.systemPackages = with pkgs; [
    vim
  ];

  security.acme.acceptTerms = true;

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
}
