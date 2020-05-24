# This module contains most of the server security settings.

{ lib, config, ... }:

with lib;

{
  options = {
    adminAuthorizedKeys = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        List of authorized SSH public keys that can access the admin account.
      '';
    };
  };

  config = let

    sshPort = 57958;

    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;

          iifname lo accept
          ct state { established, related } accept

          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept

          tcp dport ${builtins.toString sshPort} ct state new limit rate 15/minute accept

          tcp dport http accept
          tcp dport https accept
        }

        chain output {
          type filter hook output priority 0; policy accept;
        }

        chain forward {
          type filter hook forward priority 0; policy drop;
        }
      }
    '';

  in {

    networking.firewall.enable = false;
    networking.nftables = {
      enable = true;
      inherit ruleset;
    };

    services.openssh = {
      enable = true;
      ports = [ sshPort ];
      passwordAuthentication = false;
      challengeResponseAuthentication = false;
      permitRootLogin = "no";
      openFirewall = false;
    };

    security.sudo.wheelNeedsPassword = false;

    users.mutableUsers = false;
    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = config.adminAuthorizedKeys;
    };

  };
}
