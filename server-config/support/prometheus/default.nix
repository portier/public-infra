{ lib, config, ... }:

with lib;

let

  inherit (config.prometheus) virtualHost;

in {

  options.prometheus = {
    virtualHost = mkOption {
      type = types.str;
      default = "";
      description = ''
        Name of the Nginx virtual host to create.
      '';
    };
  };

  config = {

    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      webExternalUrl = "https://${virtualHost}/";

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
        {
          job_name = "nginx";
          static_configs = [ { targets = [ "127.0.0.1:9113" ]; } ];
        }
        {
          job_name = "testbroker";
          static_configs = [ { targets = [ "127.0.0.1:20080" ]; } ];
        }
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
        }
        {
          job_name = "pushgateway";
          static_configs = [ { targets = [ "127.0.0.1:9091" ]; } ];
          honor_labels = true;
        }
      ];

      exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
      };

      exporters.nginx.enable = true;

      pushgateway = {
        enable = true;
        web.listen-address = "127.0.0.1:9091";
      };
    };

    services.nginx = {
      statusPage = true;
      virtualHosts."${virtualHost}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:9090";
      };
    };

  };

}
