{ stdenv, fetchurl, python38 }:

let

  python = python38.withPackages (pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ]);

in stdenv.mkDerivation {
  name = "portier-demo";

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/403b4c8ea9d7106a6aa53661785196e5a2aa4de9.tar.gz";
    hash = "sha256-QRdywymZFqQhVjM52Fiu0qKNCoHd2y4H5/9NcjsRM9A=";
  };

  buildInputs = [ python ];
  builder = ./builder.sh;

  passthru = {
    inherit python;
  };
}
