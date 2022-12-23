{ fetchurl, bash, glibc, coreutils, gnutar, gzip, patchelf, openssl_1_1 }:

derivation {
  name = "portier-broker-0.7.2";
  system = "x86_64-linux";

  src = fetchurl {
    url = "https://github.com/portier/portier-broker/releases/download/v0.7.2/Portier-Broker-v0.7.2-Linux-x86_64.tgz";
    sha256 = "1xbmkny618akgmykdbjv0kwys2cvj5zdbywa8q7sac8dnijpc856";
  };

  inherit glibc coreutils gnutar gzip patchelf;
  openssl = openssl_1_1.out;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
