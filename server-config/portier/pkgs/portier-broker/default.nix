{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.4.1";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.4.1/Portier-Broker-v0.4.1-Linux-x86_64.tgz";
    hash = "sha256-iYZ8knUbpRWAaUyq+QAJNOI5EauEW/cUzAk6z/M5TM0=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
