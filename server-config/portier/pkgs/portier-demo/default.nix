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
    url = "https://github.com/portier/demo-rp/archive/403b4c8ea9d7106a6aa53661785196e5a2aa4de9.tar.gz";
    hash = "sha256-QRdywymZFqQhVjM52Fiu0qKNCoHd2y4H5/9NcjsRM9A=";
  };

  inherit coreutils gnutar gzip;
  python = python38.withPackages pythonPackages;

  builder = "${bash}/bin/bash";
  args = [ "-e" ./builder.sh ];
}
