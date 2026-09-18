# Polices sous licence (I Love Typography) : chiffrées parce que le dépôt est
# public, mais versionnées pour ne pas les re-télécharger sur chaque machine.
#
# Destinataires repris du store parent : une seule liste à tenir à jour lors
# d'une rotation d'identité. Après changement : `agenix -r` ici *et* à côté.
let
  publicKeys = (import ../secrets.nix)."ro-github-token.age".publicKeys;
in
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = { inherit publicKeys; };
    })
    (
      builtins.filter (n: builtins.match ".*\\.age" n != null) (builtins.attrNames (builtins.readDir ./.))
    )
)
