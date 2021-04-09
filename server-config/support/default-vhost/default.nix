# Configures a default virtual host for Nginx that does nothing.

{ pkgs, ... }:

{

  systemd.services.snake-oil-cert = {
    description = "Generate snake-oil certificate";
    wantedBy = [ "nginx.service" ];
    before = [ "nginx.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      test -d /etc/ssl/private || mkdir -p /etc/ssl/private
      cd /etc/ssl/private

      test -f snake-oil.key || \
        ${pkgs.openssl}/bin/openssl req -new -x509 -days 1000 -nodes \
          -out snake-oil.crt -keyout snake-oil.key -subj '/CN=localhost'
      chown root:nginx snake-oil.key
      chmod 640 snake-oil.key
    '';
  };

  services.nginx.virtualHosts.default = {
    default = true;
    addSSL = true;
    sslCertificate = "/etc/ssl/private/snake-oil.crt";
    sslCertificateKey = "/etc/ssl/private/snake-oil.key";
    locations."/".return = "444";
  };

}
