{ config, ... }:
{
  users.groups.media = {
    members = [
      config.services.sonarr.user
      config.services.radarr.user
      config.services.jellyfin.user
    ];
  };
  services.jellyfin = {
    enable = true;
    group = "media";
  };
  services.prowlarr = {
    enable = true;
  };
  services.sonarr = {
    enable = true;
    group = "media";
  };
  services.radarr = {
    enable = true;
    group = "media";
  };

  services.caddy.virtualHosts = {
    "jellyfin.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:8096
    '';

    "prowlarr.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.prowlarr.settings.server.port}
    '';

    "sonarr.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.sonarr.settings.server.port}
    '';

    "radarr.augendre.info".extraConfig = ''
      import common_headers
      import internal
      reverse_proxy localhost:${builtins.toString config.services.radarr.settings.server.port}"
    '';

  };
  # TODO: setup transmission -- don't forget permissions
  # https://github.com/zmitchell/nixos-configs/blob/main/modules/services/media_server.nix
  # https://github.com/rasmus-kirk/nixarr/blob/main/nixarr/transmission/default.nix
}
