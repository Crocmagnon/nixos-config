{ config, ... }:
let
  identity = import ../../../../lib/identity.nix;
in
{
  # Identité age dédiée, sans passphrase, créée à la main (hors store, hors git) :
  # `age-keygen -o ~/.config/agenix/identity.txt`. Voir ai-agents.nix.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/agenix/identity.txt" ];
  age.secrets.migadu-password.file = ./secrets/migadu-password.age;

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
