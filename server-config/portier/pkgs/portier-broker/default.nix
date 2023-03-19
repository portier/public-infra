{ fetchurl, bash, coreutils, gnutar, gzip }:

derivation {
  name = "portier-broker-0.8.0";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.8.0/Portier-Broker-v0.8.0-Linux-x86_64.tgz";
    sha256 = "0ri4rjxkskvp50ldfk5w1yj4f5c9l11jqyd2z9j3hicwi8f7smwr";
  };

  inherit coreutils gnutar gzip;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
