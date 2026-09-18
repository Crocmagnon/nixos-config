{
  config,
  pkgs,
  inputs,
  ...
}:
let
  # Identité age dédiée, sans passphrase, créée à la main (hors store, hors git) :
  # `age-keygen -o ~/.config/agenix/identity.txt`. La clé SSH par défaut a une
  # passphrase et age ne sait pas la demander à kwallet/ksshaskpass, donc ni le
  # service systemd ni la CLI ne peuvent l'utiliser sans la ressaisir.
  # À sauvegarder : sans elle, plus rien ne se déchiffre.
  identity = "${config.home.homeDirectory}/.config/agenix/identity.txt";
in
{
  # Déchiffrement des secrets dans la session (tous les modules du dossier).
  age.identityPaths = [ identity ];

  # La CLI agenix n'a ni variable d'environnement ni fichier de config pour
  # l'identité, seulement `-i`. ponytail: wrapper d'une ligne plutôt qu'un alias
  # fish — marche aussi hors shell interactif, et évite le `nix run` à chaque
  # invocation (version épinglée par le flake).
  home.packages = [
    (pkgs.writeShellScriptBin "agenix" ''
      exec ${
        inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
      }/bin/agenix -i ${identity} "$@"
    '')
  ];
}
