{ inputs, ... }:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      {
        name = "flathub-beta";
        location = "https://dl.flathub.org/beta-repo/flathub-beta.flatpakrepo";
      }
    ];

    # Les deux branches cohabitent : flatpak indexe par ref, pas par appId.
    # ponytail: flatpak n'exporte qu'un .desktop par appId (celui de la branche
    # `current`), donc une seule des deux apparaît dans le menu. L'autre se
    # lance via `flatpak run com.prusa3d.PrusaSlicer//<branch>`.
    packages = [
      {
        appId = "com.prusa3d.PrusaSlicer//stable";
        origin = "flathub";
      }
      {
        appId = "com.prusa3d.PrusaSlicer//beta";
        origin = "flathub-beta";
      }
    ];

    # Nécessaire pour suivre la tête de la branche beta.
    update.onActivation = true;
  };
}
