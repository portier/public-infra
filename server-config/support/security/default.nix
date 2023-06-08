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
    sshPortStr = builtins.toString sshPort;

    concatElements = concatStringsSep ", ";
    makeElementsInit = list: if list != [] then "elements = { ${concatElements list} };" else "";

    ruleset = ''
      table inet filter {
        # Dynamic sets for HTTP rate limits.
        set http_meter_ipv4 {
          type ipv4_addr; flags dynamic; size 65535; timeout 5s;
        }
        set http_meter_ipv6 {
          type ipv6_addr; flags dynamic; size 65535; timeout 5s;
        }

        chain input {
          type filter hook input priority 0; policy drop;

          iifname lo accept
          ct state { established, related } accept

          ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept
          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept

          # SSH. Rate limit new connections. Count drops and accepts.
          tcp dport ${sshPortStr} ct state new limit rate over 15/minute counter drop
          tcp dport ${sshPortStr} ct state new counter accept

          # HTTP. Rate limit new connections. Count drops.
          tcp dport { http, https } ct state new add @http_meter_ipv4 { ip saddr limit rate over 100/second burst 50 packets } counter drop
          tcp dport { http, https } ct state new add @http_meter_ipv6 { ip6 saddr & ffff:ffff:ffff:ffff:: limit rate over 100/second burst 50 packets } counter drop
          tcp dport { http, https } ct state new accept
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
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
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
