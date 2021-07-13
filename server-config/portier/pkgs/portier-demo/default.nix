{ stdenv, fetchurl, python39 }:

let

  python = python39.withPackages (pkgs: with pkgs; [
    pyjwt bottle cryptography fakeredis redis waitress
  ]);

in stdenv.mkDerivation {
  name = "portier-demo";

  src = fetchurl {
    url = "https://github.com/portier/demo-rp/archive/7538e9fbae59ade4dc3dde35b9e5e4f3773534cc.tar.gz";
    hash = "sha256-yXw1g9aw5DYIY2cDtspYV7kv3LjvfQT/+cJTU3JntQ4=";
  };

  buildInputs = [ python ];
  builder = ./builder.sh;

  passthru = {
    inherit python;
  };
}
