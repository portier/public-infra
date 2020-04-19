# Function that builds the nftables ruleset.

{ lib, admins }:

let
  sshRules = lib.concatMapStrings (src:
    "ip saddr ${src} tcp dport 22 accept\n"
  ) admins.allowSshFrom;
in

''
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
''
