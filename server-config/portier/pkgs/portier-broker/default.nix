{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.3.0";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.3.0/Portier-Broker-v0.3.0-Linux-x86_64.tgz";
    hash = "sha256-7ucklRaMzkjqCIGYrCjczyXDfOWHcI4QZ/PBdpIL6ZM=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
