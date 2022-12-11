{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl_1_1 }:

derivation {
  name = "portier-broker-0.7.1";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.7.1/Portier-Broker-v0.7.1-Linux-x86_64.tgz";
    sha256 = "1vpbs2l25blzmpkq8id5ng9rhfvyrc9qlifs9z8givgw3r05sp5d";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl_1_1.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
