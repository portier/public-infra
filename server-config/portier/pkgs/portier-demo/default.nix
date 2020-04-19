{ fetchurl, bash, coreutils, gnutar, gzip, python38 }:

let
  pythonPackages = pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ];
in
derivation {
  name = "portier-demo";
  system = builtins.currentSystem;

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/577310e9fe47da59a8d49064dd56efa6141243b4.tar.gz";
    hash = "sha256-wvL9TyTzRfkAN6KiYZ9qX0ijGpcksUB3FBhl2IBJhvo=";
  };

  inherit coreutils gnutar gzip;
  python = python38.withPackages pythonPackages;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
