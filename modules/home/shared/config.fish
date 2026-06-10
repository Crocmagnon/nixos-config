set -g fish_greeting ""
if type -q devenv
    devenv hook fish | source
end
