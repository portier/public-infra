{

  inputs.nixpkgs.url = "nixpkgs/nixos-21.05-small";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./server-config/configuration.nix ];
    };
  };

}
