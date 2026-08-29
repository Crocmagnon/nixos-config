set -g fish_greeting ""

# le thème catppuccin ne définit pas fish_color_valid_path (contrairement au
# thème fish par défaut) -> on remet le soulignement des chemins existants
set -g fish_color_valid_path --underline

if type -q devenv
    devenv hook fish | source
end
