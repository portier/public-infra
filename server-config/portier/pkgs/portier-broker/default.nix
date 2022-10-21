{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.7.0";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.7.0/Portier-Broker-v0.7.0-Linux-x86_64.tgz";
    hash = "sha256-UDY58bICl2gHuOMh4ObUFV6BsJ3507N2QfiU1+0V+N4=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
