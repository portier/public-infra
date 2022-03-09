{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.6.1";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.6.1/Portier-Broker-v0.6.1-Linux-x86_64.tgz";
    hash = "sha256-a4Uxpt1u/l5zwcE3wLiNQCBW30NiaPuoB40lMtFZlzs=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
