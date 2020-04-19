# NixOS module that allows running Portier packages as services.

{
  imports = [
    ./modules/portier-broker.nix
    ./modules/portier-demo.nix
  ];
  config.nixpkgs.overlays = [
    (import ../default.nix)
  ];
}
