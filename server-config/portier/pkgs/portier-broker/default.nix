{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.6.0";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.6.0/Portier-Broker-v0.6.0-Linux-x86_64.tgz";
    hash = "sha256-XyQPba3UmDCKo1SrPLcei0KK1AhY61Kg5D2/9GlRXrI=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
