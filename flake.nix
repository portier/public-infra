{

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";

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

  outputs = { nixpkgs, ... } @ flakeInputs: rec {

    nixosConfigurations.public-portier = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Make flakeInputs available in module args.
        { _module.args = { inherit flakeInputs; }; }
        # Main server configuration.
        ./server-config/configuration.nix
        # Set a NIX_PATH to match the system Nixpkgs, so e.g. nix-shell works.
        ({ lib, ... }: { nix.nixPath = lib.mkForce [ "nixpkgs=${nixpkgs}" ]; })
      ];
    };

    # For easy `nix build`.
    packages.x86_64-linux.default = nixosConfigurations.public-portier.config.system.build.toplevel;

  };

}
