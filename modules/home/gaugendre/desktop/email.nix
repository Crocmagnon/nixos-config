{ ... }:
let
  identity = import ../../../../lib/identity.nix;
in
{
  accounts.email.accounts.Migadu = {
    enable = true;
    flavor = "migadu.com";
    primary = true;
    realName = identity.fullName;
    thunderbird.enable = true;
    userName = identity.email;
    address = identity.email;
  };
  programs.thunderbird = {
    enable = true;
    profiles.migadu.isDefault = true;
  };
}
