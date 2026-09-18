{ lib, ... }:
let
  secrets = lib.mapAttrs' (
    name: value: lib.nameValuePair (lib.strings.removeSuffix ".age" name) { file = ./${name}; }
  ) (import ./secrets.nix);
in
{
  age.secrets = lib.attrsets.recursiveUpdate secrets {
    paperless-env.owner = "paperless";
    downloader-creds-env.owner = "paperless";
    transmission-credentials.owner = "transmission";
    # calibre-library-sync tourne en calibre-web et doit lire le remote pcloud-gab.
    # pcloud-sync tourne en root et continue de pouvoir le lire.
    rclone-config.owner = "calibre-web";
  };
}
