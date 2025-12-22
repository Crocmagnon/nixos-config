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
    syncthing-gui-password.owner = "syncthing";
  };
}
