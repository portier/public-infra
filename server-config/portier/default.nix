# Nixpkgs overlay containing Portier packages.

self: super:

{
  portier-demo = super.callPackage ./pkgs/portier-demo {};
}
