{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.3.5";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.3.5/Portier-Broker-v0.3.5-Linux-x86_64.tgz";
    hash = "sha256-YKMYwPzOI/8OcdGB4dSBfpAeLwvbrtQhjLAWsoV7zCs=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
