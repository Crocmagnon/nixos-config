{
  config,
  lib,
  pkgs,
  ...
}:
let
  # bashOptions vidé : le script enchaîne des `[ ... ] && ...` dont l'échec est
  # le cas normal, et `set -e` couperait la statusline à la première branche
  # fausse.
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
    ];
    bashOptions = [ ];
    text = builtins.readFile ./claude-statusline.sh;
  };
in
{
  # node is required by the ponytail plugin
  # herdr : pas de module home-manager en release-26.05, donc juste le paquet.
  # Son thème est configuré plus bas, dans herdr/config.toml.
  home.packages = [
    pkgs.nodejs
    pkgs.herdr
  ];

  # Une fenêtre kitty ouvre herdr et non fish : herdr gère son propre shell
  # (terminal.default_shell ci-dessous).
  programs.kitty.settings.startup_session = "herdr.session";
  xdg.configFile."kitty/herdr.session".text = "launch ${lib.getExe pkgs.herdr}\n";

  # Pas de module home-manager pour herdr, donc le TOML à la main. herdr s'abonne
  # à OSC 2031 et relaie la couleur de fond de kitty aux enfants des panes, donc
  # auto_switch suffit à le faire suivre.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [theme]
    auto_switch = true
    dark_name = "catppuccin-mocha"
    light_name = "catppuccin-latte"

    [ui]
    agent_panel_sort = "priority"
    show_agent_labels_on_pane_borders = true
    mouse_capture = true

    [ui.toast]
    delivery = "system"

    [terminal]
    default_shell = "${lib.getExe pkgs.fish}"
  '';

  age.secrets.ha-mcp-token.file = ./age/ha-mcp-token.age;

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    rules.workflow = ./claude-rules-workflow.md;

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
      # « Auto (match terminal) » : claude interroge OSC 11 avec repli sur
      # COLORFGBG. Confirmé au démarrage d'une session.
      theme = "auto";
      tui = "fullscreen";
      language = "french";
      # Sinon une question sans réponse finit par se valider toute seule avec ce
      # qui est sélectionné à ce moment-là.
      askUserQuestionTimeout = "never";
      # Marque l'opt-in du mode auto comme accepté, vu que defaultMode l'est déjà.
      skipAutoPermissionPrompt = true;

      env.FORCE_HYPERLINK = "1";

      statusLine = {
        type = "command";
        command = lib.getExe statusline;
      };
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

          "Read(**/*.enc)"
          "Read(**/*.key)"
          "Read(**/*.pem)"
          "Read(**/.env)"
          "Read(**/.env.*)"
          "Read(**/.terraformrc)"
          "Read(**/credentials.json)"
          "Read(**/id_dsa)"
          "Read(**/id_ecdsa)"
          "Read(**/id_ed25519)"
          "Read(**/id_rsa)"
          "Read(**/secrets.json)"
          "Read(**/terraform.rc)"
          "Read(**/vault.yaml)"
          "Read(**/vault.yml)"
          "Read(*.tfstate)"
          "Read(*.tfvars)"
        ];
      };
      # Reproduit `herdr integration install claude` : herdr sait poser
      # ~/.claude/hooks/herdr-agent-state.sh, mais pas déclarer le hook dans
      # settings.json, read-only car géré par home-manager. Sur une machine
      # neuve, lancer `herdr integration install claude` une fois pour le script.
      hooks.SessionStart = [
        {
          matcher = "^(startup|resume|clear|compact|fork)$";
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
      extraKnownMarketplaces.goland-claude-marketplace.source = {
        source = "github";
        repo = "JetBrains/go-modern-guidelines";
      };
      enabledPlugins."ponytail@ponytail" = true;
      enabledPlugins."superpowers@claude-plugins-official" = true;
      enabledPlugins."gopls-lsp@claude-plugins-official" = true;
      enabledPlugins."modern-go-guidelines@goland-claude-marketplace" = true;
    };
  };
}
