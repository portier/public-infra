{
  services.unbound = {
    enable = true;
    settings.server = {
      cache-min-ttl = 30;
      prefetch = true;
      prefetch-key = true;
    };
  };
}
