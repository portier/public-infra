{ stdenv, fetchurl, python39 }:

let

  python = python39.withPackages (pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ]);

in stdenv.mkDerivation {
  name = "portier-demo";

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/6d61103f7472afa2acd5ffb1d2b27dd1f9877c44.tar.gz";
    hash = "sha256-Rr3H8MQ+ur+R2k1nSvUjeG2rY/xFXyrqOBdZ4YQzzmE=";
  };

  buildInputs = [ python ];
  builder = ./builder.sh;

  passthru = {
    inherit python;
  };
}
