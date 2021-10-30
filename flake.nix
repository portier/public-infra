{

  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";
  inputs.nixpkgs_old.url = "nixpkgs/aff647e2704fa1223994604887bb78276dc57083";

  outputs = { self, nixpkgs, nixpkgs_old }: rec {

    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Main server configuration.
        ./server-config/configuration.nix
        # Set a NIX_PATH to match the system Nixpkgs, so e.g. nix-shell works.
        ({ lib, ... }: { nix.nixPath = lib.mkForce [ "nixpkgs=${nixpkgs}" ]; })
        # FIXME: https://github.com/portier/public-infra/issues/14
        ({ pkgs, ... }: {
          boot.kernelPackages = let
            pkgs_old = import nixpkgs_old {
              inherit (pkgs) system;
            };
          in pkgs_old.linuxPackages_hardened;
        })
      ];
    };

    # For easy `nix build`.
    defaultPackage.x86_64-linux = nixosConfigurations.public-portier.config.system.build.toplevel;

  };

}
