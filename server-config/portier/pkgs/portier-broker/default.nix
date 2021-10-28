{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl }:

derivation {
  name = "portier-broker-0.5.2";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.5.2/Portier-Broker-v0.5.2-Linux-x86_64.tgz";
    hash = "sha256-kSeo3zcECfZf8eYWgJ23SGgC4y0IU0qnZIa8P06tVKg=";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
