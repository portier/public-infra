{

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";

    # These match `moduleName` in the NixOS modules.
    portier-broker = {
      url = "github:portier/portier-broker/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    portier-broker-testing = {
      url = "github:portier/portier-broker/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, portier-broker, portier-broker-testing }: {

    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ lib, ... }: {
          # Set a NIX_PATH to match the system Nixpkgs, so e.g. nix-shell works.
          nix.nixPath = lib.mkForce [ "nixpkgs=${nixpkgs}" ];
          # Add portier-broker overlays.
          nixpkgs.overlays = [
            portier-broker.overlays.default
            # Rename attribute for the testing overlay.
            (final: prev: {
              portier-broker-testing =
                (portier-broker-testing.overlays.default final prev)
                  .portier-broker;
            })
          ];
        })
        # Main server configuration.
        ./server-config/configuration.nix
      ];
    };

    # For easy `nix build`.
    packages.x86_64-linux.default = self.nixosConfigurations.public-portier.config.system.build.toplevel;

    devShells = builtins.mapAttrs (system: pkgs: {
      default = pkgs.mkShellNoCC {
        packages = [ pkgs.nixos-rebuild ];
      };
    }) nixpkgs.legacyPackages;

  };

}
