# Main configuration file.
#
# This configures various system settings, sets up SSH access, and a baseline
# Nginx. On top of this, other modules we import prepare the actual Portier
# installations.

{ pkgs, lib, ... }:

let
  admins = import ./admins.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./local-configuration.nix
    ./support/portier-environments.nix
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
  };
  nix.gc.automatic = true;

  boot.loader.timeout = 0;
  boot.enableContainers = false;
  appstream.enable = false;
  documentation.enable = false;

  networking.useDHCP = false;
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    ruleset = import ./nft-ruleset.nix { inherit lib admins; };
  };

  users.mutableUsers = false;
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = admins.authorizedKeys;
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  security.sudo.wheelNeedsPassword = false;

  security.acme.acceptTerms = true;

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "no";
    openFirewall = false;
  };

  systemd.services.snake-oil-cert = {
    description = "Generate snake-oil certificate";
    wantedBy = [ "nginx.service" ];
    before = [ "nginx.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      test -d /etc/ssl/private || mkdir -p /etc/ssl/private
      cd /etc/ssl/private

      test -f snake-oil.key || \
        ${pkgs.openssl}/bin/openssl req -new -x509 -days 1000 -nodes \
          -out snake-oil.crt -keyout snake-oil.key -subj '/CN=localhost'
      chown root:nginx snake-oil.key
      chmod 640 snake-oil.key
    '';
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "localhost" = {
        default = true;
        addSSL = true;
        sslCertificate = "/etc/ssl/private/snake-oil.crt";
        sslCertificateKey = "/etc/ssl/private/snake-oil.key";
        locations."/".return = "444";
      };
    };
  };
}
