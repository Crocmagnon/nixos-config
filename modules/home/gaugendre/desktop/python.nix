{ pkgs, ... }:
{
  programs.uv = {
    enable = true;
    package = pkgs.uv;
  };

  home.sessionVariables = {
    MISE_PYTHON_VENV_AUTO_CREATE = "true";
    PIP_REQUIRE_VIRTUALENV = "true";
    # starship affiche déjà le venv ; sans ça les scripts d'activation en
    # ajoutent un second entre parenthèses.
    VIRTUAL_ENV_DISABLE_PROMPT = "1";
  };
}
