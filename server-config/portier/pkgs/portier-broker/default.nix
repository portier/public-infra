{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.5.0";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.5.0/Portier-Broker-v0.5.0-Linux-x86_64.tgz";
    hash = "sha256-VJPI/ETVQVprRn+UcHkF+1lDPFc+1A3UEAoSVouA01E=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
