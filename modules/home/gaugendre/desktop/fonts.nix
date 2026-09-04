{ config, lib, ... }:
let
  fontsDir = ./secrets/fonts;
  # ponytail: readDir plutôt que 16 déclarations à la main ; déposer un
  # `<nom>.otf.age` dans le dossier suffit à installer la police.
  encrypted = builtins.filter (lib.hasSuffix ".age") (builtins.attrNames (builtins.readDir fontsDir));
in
{
  # Polices payantes : impossible d'en faire un paquet Nix (les sources
  # seraient en clair dans un dépôt public), donc agenix les déchiffre dans la
  # session et les expose via ~/.local/share/fonts, que fontconfig scanne.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/agenix/identity.txt" ];
  age.secrets = builtins.listToAttrs (
    map (
      file:
      let
        name = lib.removeSuffix ".age" file;
      in
      lib.nameValuePair name {
        file = fontsDir + "/${file}";
        path = "${config.home.homeDirectory}/.local/share/fonts/${name}";
      }
    ) encrypted
  );
}
