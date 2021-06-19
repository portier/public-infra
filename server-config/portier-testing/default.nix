# Nixpkgs overlay that provides testing versions of Portier packages.

let

  sources = builtins.fromJSON (builtins.readFile ./sources.json);

in self: super: {

  portier-broker-testing = derivation (self.portier-broker.drvAttrs // {
    name = "portier-broker-testing";

    testsrc = super.fetchurl (sources.broker // {
      name = "portier-broker-testing.zip";
      # We download an artifact, which requires some authentication to the
      # GitHub API, even though it is otherwise public. (Even GitHub web blocks
      # anonymous downloads of these.)
      netrcImpureEnvVars = [ "GITHUB_TOKEN" ];
      netrcPhase = ''
        if [ -z "$GITHUB_TOKEN" ]; then
          echo "Error: nix builder must have GITHUB_TOKEN env var set." >&2
          exit 1
        fi
        cat > netrc <<EOF
        machine api.github.com
          login token
          password $GITHUB_TOKEN
        EOF
      '';
    });

    # The artifact contains the binary only. Combine it with release data.
    inherit (self) unzip;
    builder = "${self.bash}/bin/bash";
    args = [ "-e" ./build-testing-broker.sh ];
  });

  portier-demo-testing = self.portier-demo.overrideAttrs (old: {
    name = "portier-demo-testing";
    src = super.fetchurl (sources.demo // {
      name = "portier-demo-testing.zip";
    });
  });

}
