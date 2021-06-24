# Main configuration file.
#
# This configures various system settings and imports other modules to do most
# of the actual configuration.

{ pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/hardened.nix"
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/minimal.nix"
    ./hardware-configuration.nix
    ./local-configuration.nix
    ./portier/nixos
    ./portier-testing/nixos
    ./support/autotest
    ./support/default-vhost
    ./support/portier-environments
    ./support/security
    ./support/prometheus
    ./support/webhook
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };

  nix = {
    # Reduce daemon priority.
    daemonNiceLevel = 5;
    daemonIONiceLevel = 5;
    # Use our Cachix binary cache, filled by GitHub Actions.
    binaryCaches = [ "https://portier.cachix.org" ];
    binaryCachePublicKeys = [ "portier.cachix.org-1:thI6UJMG/LFzmEGS8LExOlwwjSWvqsSeb/skVOCFbds=" ];
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

  services.chrony.enable = true;

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  # The hardened profile sets scudo, but it causes instability.
  environment.memoryAllocator.provider = "libc";
}
