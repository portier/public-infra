# This module provides testing versions of packages. These need to be placed in
# `./downloads`, which is arranged by the webhook. If a download is missing, we
# fall back to the regular package.

let

  overlay = self: super: {

    portier-broker-testing =
      if builtins.pathExists ./downloads/portier-broker-testing.zip then
        derivation (self.portier-broker.drvAttrs // {
          name = "portier-broker-3f11d4d";
          testsrc = ./downloads/portier-broker-testing.zip;

          inherit (self) unzip;
          builder = "${self.bash}/bin/bash";
          args = [ "-e" ./build-testing-broker.sh ];
        })
      else self.portier-broker;

    portier-demo-testing =
      if builtins.pathExists ./downloads/portier-demo-testing.tar.gz then
        derivation (self.portier-demo.drvAttrs // {
          name = "portier-demo-e96f8d1";
          src = ./downloads/portier-demo-testing.tar.gz;
        })
      else self.portier-demo;

  };

in {
  config.nixpkgs.overlays = [ overlay ];
}
