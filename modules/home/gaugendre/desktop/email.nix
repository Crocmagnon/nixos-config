{ config, ... }:
let
  identity = import ../../../../lib/identity.nix;
in
{
  age.secrets.migadu-password.file = ./age/migadu-password.age;

  accounts.email.accounts.Migadu = {
    enable = true;
    flavor = "migadu.com";
    primary = true;
    realName = identity.fullName;
    thunderbird.enable = true;
    himalaya.enable = true;
    userName = identity.email;
    address = identity.email;
    # himalaya passe `auth.cmd` à un shell, donc le ${XDG_RUNTIME_DIR} du chemin
    # agenix est développé à l'exécution.
    passwordCommand = "cat ${config.age.secrets.migadu-password.path}";
  };
  programs.himalaya.enable = true;
  programs.thunderbird = {
    enable = true;
    profiles.migadu.isDefault = true;
  };
}
