# Nixpkgs overlay that provides testing versions of Portier packages.

let

  sources = builtins.fromJSON (builtins.readFile ./sources.json);

in self: super: {

  portier-demo-testing = self.portier-demo.overrideAttrs (old: {
    name = "portier-demo-testing";
    src = super.fetchurl (sources.demo // {
      name = "portier-demo-testing.zip";
    });
  });

}
