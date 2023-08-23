{ stdenv, fetchurl, python3 }:

let

  python = python3.withPackages (pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ]);

in stdenv.mkDerivation {
  name = "portier-demo";

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/42294b2084e1aaef643b62f3a6eb830965cb86d4.tar.gz";
    hash = "sha256-mj6boWLuMhaErYdcXVWJt2H9xo7IKaNZiiP6DzAv2iA=";
  };

  buildInputs = [ python ];
  builder = ./builder.sh;

  passthru = {
    inherit python;
  };
}
