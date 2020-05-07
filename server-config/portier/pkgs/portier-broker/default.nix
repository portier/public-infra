{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.3.2";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.3.2/Portier-Broker-v0.3.2-Linux-x86_64.tgz";
    hash = "sha256-lGUUWRqtaIPaAb++qsy9RxBnvxVMLEiYo+NHskp8Tb4=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
