{ config, ... }:
{
  # PAT fine-grained « public repositories, read-only ». Sans lui, mise et nix
  # tapent l'API GitHub en anonyme (60 req/h partagées par IP) et finissent en
  # 403 : mise n'arrive plus à lister les versions, nix à résoudre un input.
  #
  # Identité age dédiée, sans passphrase : voir le commentaire dans ai-agents.nix.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/agenix/identity.txt" ];
  age.secrets.ro-github-token.file = ./secrets/ro-github-token.age;

  # ponytail: agenix écrit un fichier, les outils lisent des variables d'env.
  # Un `cat` au démarrage du shell suffit.
  #
  # GITHUB_API_TOKEN plutôt que GITHUB_TOKEN : gh préfère GITHUB_TOKEN au
  # trousseau, et ce token read-only lui ferait perdre les scopes repo/gist.
  # gh ignore GITHUB_API_TOKEN, que mise lit tout aussi bien.
  #
  # nix ne lit aucune des deux, il veut `access-tokens` ; NIX_CONFIG est la
  # seule voie qui ne mette pas le token dans le store (dépôt public).
  #
  # Le `test -r` couvre le tout premier login, où le shell peut démarrer avant
  # le service de déchiffrement.
  programs.fish.interactiveShellInit = ''
    if test -r ${config.age.secrets.ro-github-token.path}
        set -gx GITHUB_API_TOKEN (cat ${config.age.secrets.ro-github-token.path})
        set -gx NIX_CONFIG "access-tokens = github.com=$GITHUB_API_TOKEN"
    end
  '';
}
