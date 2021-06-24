{

  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }: rec {

    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./server-config/configuration.nix ];
    };

    # For easy `nix build`.
    defaultPackage.x86_64-linux = nixosConfigurations.public-portier.config.system.build.toplevel;

  };

}
