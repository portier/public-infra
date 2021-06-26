# Variant of Portier NixOS module for testing.

{
  imports = [
    ./modules/portier-broker.nix
    ./modules/portier-demo.nix
  ];
  config.nixpkgs.overlays = [
    (import ../default.nix)
  ];
}
