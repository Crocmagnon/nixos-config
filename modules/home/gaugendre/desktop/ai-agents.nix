{
  config,
  lib,
  pkgs,
  ...
}:
{
  # node is required by the ponytail plugin
  # herdr : pas de module home-manager en release-26.05 ni de thème catppuccin,
  # donc juste le paquet.
  home.packages = [
    pkgs.nodejs
    pkgs.herdr
  ];

  # Identité age dédiée, sans passphrase, créée à la main (hors store, hors git) :
  # `age-keygen -o ~/.config/agenix/identity.txt`. La clé SSH par défaut a une
  # passphrase et age ne sait pas la demander à kwallet/ksshaskpass, donc le
  # service systemd ne peut pas l'utiliser.
  age.identityPaths = [ "${config.home.homeDirectory}/.config/agenix/identity.txt" ];
  age.secrets.ha-mcp-token.file = ./secrets/ha-mcp-token.age;

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    mcpServers.nixos = {
      type = "stdio";
      command = lib.getExe pkgs.mcp-nixos;
    };

    # ha-mcp tourne en local et parle à l'API REST de HA : pas d'OAuth. Le flux
    # OAuth via le webhook est cassé côté HA (IndieAuth compare le redirect_uri
    # à l'identique, or Claude Code annonce http://localhost/callback sans port
    # et écoute sur un port dynamique → « Invalid redirect URI »).
    # Host joignable uniquement via tailscale.
    mcpServers.home-assistant = {
      type = "stdio";
      # ponytail: agenix n'écrit qu'un fichier, ha-mcp ne lit qu'une variable
      # d'env. Un `bash -c` suffit, pas besoin d'un wrapper packagé.
      command = "${pkgs.bash}/bin/bash";
      args = [
        "-c"
        ''HOMEASSISTANT_TOKEN="$(cat ${config.age.secrets.ha-mcp-token.path})" exec ${pkgs.ha-mcp}/bin/ha-mcp''
      ];
      env = {
        HOMEASSISTANT_URL = "https://hass.augendre.info";
        # Les outils de l'entrée « HA-MCP File & YAML Tools » sont désactivés
        # par défaut côté serveur. ENABLE_BETA_FEATURES est le master : sans
        # lui les deux sous-drapeaux sont ignorés à l'exécution.
        ENABLE_BETA_FEATURES = "true";
        HAMCP_ENABLE_FILESYSTEM_TOOLS = "true"; # ha_{list,read,write,delete}_file
        ENABLE_YAML_CONFIG_EDITING = "true"; # ha_config_set_yaml
      };
    };

    settings = {
      theme = "auto";
      tui = "fullscreen";
      language = "french";
      permissions = {
        defaultMode = "auto";
        allow = [
          "Bash(git status:*)"
          "Bash(git diff:*)"
          "Bash(git log:*)"
          "Bash(git branch:*)"
          "Bash(git show:*)"
          "Bash(nix flake check:*)"
          "Bash(nix build:*)"
          "Bash(nix eval:*)"
          "Bash(nixos-rebuild dry-build:*)"
          "Bash(nixos-rebuild dry-activate:*)"
        ];
        deny = [
          "Bash(curl:*)"
          "Bash(wget:*)"
        ];
      };
      # Reproduit `herdr integration install claude` : herdr sait poser
      # ~/.claude/hooks/herdr-agent-state.sh, mais pas déclarer le hook dans
      # settings.json, read-only car géré par home-manager. Sur une machine
      # neuve, lancer `herdr integration install claude` une fois pour le script.
      hooks.SessionStart = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "bash '${config.home.homeDirectory}/.claude/hooks/herdr-agent-state.sh' session";
              timeout = 10;
            }
          ];
        }
      ];

      extraKnownMarketplaces.ponytail.source = {
        source = "github";
        repo = "DietrichGebert/ponytail";
      };
      enabledPlugins."ponytail@ponytail" = true;
      enabledPlugins."superpowers@claude-plugins-official" = true;
    };
  };
}
