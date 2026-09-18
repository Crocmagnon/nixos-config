let
  # Déchiffrement dans la session utilisateur (module home-manager d'agenix),
  # pas au boot : pas besoin de clé d'hôte — les desktops n'en ont pas
  # (`services.openssh` désactivé).
  #
  # L'identité de déchiffrement est une clé age dédiée, sans passphrase, hors
  # du store et hors de git (voir `age.identityPaths` dans ../agenix.nix) :
  # `~/.ssh/id_ed25519` a une passphrase, et age ne sait pas la demander à
  # kwallet/ksshaskpass — le service systemd échouerait. C'est la même clé que
  # `gaugendre-age` côté srv-1 (partagée entre les desktops, sauvegardée dans
  # Bitwarden) ; la CLI l'utilise via le wrapper de ../agenix.nix, qui force `-i`.
  #
  # `gaugendre-laptop` est un secours si la clé age était perdue. La clé SSH du
  # desktop n'est volontairement pas destinataire ici : elle le serait pour un
  # secours de plus, au prix d'un rekey, alors que la clé age est sauvegardée.
  identities = {
    gaugendre-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBZRv1LUKsDbrjGJh051NCu40x9edBpERi68PgSzDW4";
    gaugendre-age = "age1el8d8hfa76kta040rhva7u64pfkuc8d6sujttqrq0tf7je0wqetqkz5hd9";
  };
  all = builtins.attrValues identities;
in
{
  "ha-mcp-token.age".publicKeys = all;
  "migadu-password.age".publicKeys = all;
  "ro-github-token.age".publicKeys = all;
}
