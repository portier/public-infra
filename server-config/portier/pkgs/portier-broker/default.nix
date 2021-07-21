{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.4.2";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.4.2/Portier-Broker-v0.4.2-Linux-x86_64.tgz";
    hash = "sha256-UgclK9pJw9ffF25Bxpy9eTC4XezpNbzqt+aMBCFzkEc=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
