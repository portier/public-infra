{ stdenv, fetchurl, python3 }:

let

  python = python3.withPackages (pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ]);

in stdenv.mkDerivation {
  name = "portier-demo";

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/7f261937da921a4a7de820375c9c238e01ff86fe.tar.gz";
    hash = "sha256-jK/sq6zlLP9acAy71/0PVQ4lquCU497UBwgFGL764pE=";
  };

  buildInputs = [ python ];
  builder = ./builder.sh;

  passthru = {
    inherit python;
  };
}
