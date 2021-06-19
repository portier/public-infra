# Nixpkgs overlay containing Portier packages.

self: super:

{
  portier-broker = super.callPackage ./pkgs/portier-broker {};
  portier-demo = super.callPackage ./pkgs/portier-demo {};
}
