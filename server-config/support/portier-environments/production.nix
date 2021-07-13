{ lib, config, ... }:

let

  cfg = config.portier;

  # We maintain the module for testing as a copy of production, so we can
  # easily test module changes. These variables contain the main differences
  # between the two. Using variables allows easier diffing.
  env = cfg.production;
  broker.module = "portier-broker";
  broker.port = 30080;
  demo.module = "portier-demo";
  demo.port = 30081;

in {

  services.${broker.module} = {
    enable = env.broker.enable;
    port = broker.port;
    publicUrl = "https://${env.broker.vhost}";
    verifyWithResolver = "127.0.0.1:53";
    verifyPublicIp = true;
    inherit (cfg) fromName fromAddress smtpServer googleClientId configFile;
  };


  services.${demo.module} = {
    enable = env.demo.enable;
    port = demo.port;
    websiteUrl = "https://${env.demo.vhost}";
    brokerUrl = "https://${env.broker.vhost}";
  };

  services.nginx.virtualHosts = {

    ${env.broker.vhost} = lib.mkIf env.broker.enable {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString broker.port}";
    };

    ${env.demo.vhost} = lib.mkIf env.demo.enable {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:${toString demo.port}";
    };

  };

}
