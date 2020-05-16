# This module contains most of the server security settings.

{ lib, config, ... }:

with lib;

{
  options = {
    allowSshFrom = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        List of IPv4 or IPv6 addresses or subnets (in CIDR notation) to allow
        SSH connections from.
      '';
    };
    adminAuthorizedKeys = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        List of authorized SSH public keys that can access the admin account.
      '';
    };
  };

  config = let

    sshRules = concatMapStrings (src:
      "ip saddr ${src} tcp dport 22 accept\n"
    ) config.allowSshFrom;

    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;

          iifname lo accept
          ct state { established, related } accept

          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept

          ${sshRules}

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
