{

  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }: rec {

    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Main server configuration.
        ./server-config/configuration.nix
        # Set a NIX_PATH to match the system Nixpkgs, so e.g. nix-shell works.
        ({ lib, ... }: { nix.nixPath = lib.mkForce [ "nixpkgs=${nixpkgs}" ]; })
      ];
    };

    # For easy `nix build`.
    defaultPackage.x86_64-linux = nixosConfigurations.public-portier.config.system.build.toplevel;

  };

}
