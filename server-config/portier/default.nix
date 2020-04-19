# Nixpkgs overlay containing Portier packages and dependencies.

self: super:

{
  portier-broker = super.callPackage ./pkgs/portier-broker {};
  portier-demo = super.callPackage ./pkgs/portier-demo {};

  python38 = super.python38.override {
    packageOverrides = self: super: {
      fakeredis = super.callPackage ./python-modules/fakeredis {};
    };
  };
}
