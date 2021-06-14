# Nixpkgs overlay containing Portier packages and dependencies.

self: super:

{
  portier-broker = super.callPackage ./pkgs/portier-broker {};
  portier-demo = super.callPackage ./pkgs/portier-demo {};
}
