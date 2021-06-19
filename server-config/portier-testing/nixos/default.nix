{
  config.nixpkgs.overlays = [
    (import ../default.nix)
  ];
}
