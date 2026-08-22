let
  # Déchiffrement dans la session utilisateur (module home-manager d'agenix),
  # pas au boot : pas besoin de clé d'hôte — les desktops n'en ont pas
  # (`services.openssh` désactivé).
  #
  # L'identité de déchiffrement est une clé age dédiée, sans passphrase, hors
  # du store et hors de git (voir `age.identityPaths` dans ai-agents.nix) :
  # `~/.ssh/id_ed25519` a une passphrase, et age ne sait pas la demander à
  # kwallet/ksshaskpass — le service systemd échouerait.
  #
  # La clé SSH reste destinataire pour que `agenix -e`/`-r` fonctionne avec
  # l'identité par défaut (passphrase saisie sur le tty).
  identities = {
    gaugendre-ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBZRv1LUKsDbrjGJh051NCu40x9edBpERi68PgSzDW4";
    framework-gab-agenix = "age1el8d8hfa76kta040rhva7u64pfkuc8d6sujttqrq0tf7je0wqetqkz5hd9";
  };
  all = builtins.attrValues identities;
in
{
  "ha-mcp-token.age".publicKeys = all;
}
