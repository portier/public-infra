{

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";

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
      ];
    };

    # For easy `nix build`.
    packages.x86_64-linux.default = nixosConfigurations.public-portier.config.system.build.toplevel;

    devShells = builtins.mapAttrs (system: pkgs: {
      default = pkgs.mkShellNoCC {
        packages = [ pkgs.nixos-rebuild ];
      };
    }) nixpkgs.legacyPackages;

  };

}
