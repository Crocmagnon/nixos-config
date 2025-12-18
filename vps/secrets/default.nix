{lib, ...}:
{
  age.secrets = lib.mapAttrs' (name: value: lib.nameValuePair (lib.strings.removeSuffix ".age" name) ({file = ./${name};})) (import ./secrets.nix);
}
