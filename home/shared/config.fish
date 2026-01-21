set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -g fish_greeting ""

# fix man output with bat (remove color codes)
set -x GROFF_NO_SGR 1

fish_add_path --global (go env GOPATH)/bin
