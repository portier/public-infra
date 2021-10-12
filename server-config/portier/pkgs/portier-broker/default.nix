{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.5.1";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.5.1/Portier-Broker-v0.5.1-Linux-x86_64.tgz";
    hash = "sha256-ZzyicdUeW1AxGAAkRFNN6A92ps1rCJR0UK81hOSvBLQ=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
