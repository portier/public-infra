{ fetchurl, bash, coreutils, gnutar, gzip }:

derivation {
  name = "portier-broker-0.8.2";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.8.2/Portier-Broker-v0.8.2-Linux-x86_64.tgz";
    sha256 = "07fq20r0vacfwmniab84rzbbx3l6yx0wg2a3m520psc9xnrila59";
  };

  inherit coreutils gnutar gzip;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
