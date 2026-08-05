# Outils de mesure de la batterie (baseline avant réglages d'économie d'énergie).
# Aucun réglage n'est appliqué ici : uniquement de l'instrumentation prête à l'emploi.
# Protocole de mesure documenté dans le plan associé.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    powertop # analyse détaillée de la conso en éveil + suggestions
    powerstat # log du taux de décharge sur la durée (éveil)
    acpi # état batterie rapide
    # upower est déjà présent (tiré par Plasma)
  ];
}
