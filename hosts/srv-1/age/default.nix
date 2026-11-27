{ lib, ... }:
let
  secrets = lib.mapAttrs' (
    name: value: lib.nameValuePair (lib.strings.removeSuffix ".age" name) { file = ./${name}; }
  ) (import ./agenix-rules.nix);
in
{
  age.secrets = lib.attrsets.recursiveUpdate secrets {
    paperless-env.owner = "paperless";
    downloader-creds-env.owner = "paperless";
    transmission-credentials.owner = "transmission";
    authelia-jwt.owner = "authelia-main";
    authelia-storage-key.owner = "authelia-main";
    authelia-oidc-hmac.owner = "authelia-main";
    authelia-oidc-jwk.owner = "authelia-main";
    authelia-users.owner = "authelia-main";
  };
}
