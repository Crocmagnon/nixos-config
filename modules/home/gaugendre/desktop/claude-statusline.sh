# Statusline Claude Code : modèle | repo[worktree]:branche*↑↓ | barre de contexte | coût
# Packagé par ai-agents.nix, qui fournit jq et git.

# locale.nix met LC_NUMERIC=fr_FR, où printf '%.2f' rejette « 1.2345 » et
# retombe sur 0 : le coût s'affichait $1,00. C stabilise aussi la sortie de git.
export LC_ALL=C

input=$(cat)

IFS=$'\t' read -r model dir used cost < <(jq -r '[
  .model.display_name // "?",
  (.workspace.current_dir // .cwd // "."),
  (.context_window.used_percentage // -1),
  (.cost.total_cost_usd // 0)
] | @tsv' <<<"$input")

R=$'\e[0m' DIM=$'\e[2m' REPO=$'\e[1;34m' BRANCH=$'\e[35m'
# Couleurs de barre en fond : kitty rend les glyphes de remplissage avec son
# propre tramage, donc la barre est faite de cellules vides. La piste est
# l'accent à 25 % sur la base Latte.
RED=$'\e[48;2;210;15;57m'  RED_T=$'\e[48;2;232;185;198m'
YEL=$'\e[48;2;223;142;29m' YEL_T=$'\e[48;2;235;216;191m'
GRN=$'\e[48;2;64;160;43m'  GRN_T=$'\e[48;2;195;221;195m'
SEP="${DIM} | ${R}"

out="${DIM}${model}${R}"

if root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
  # Dans un worktree lié, le common dir est le .git du clone principal : les
  # deux noms diffèrent.
  repo=$(basename "$(dirname "$(cd "$dir" && git rev-parse --path-format=absolute --git-common-dir)")")
  wt=$(basename "$root")
  loc="${REPO}${repo}${R}"
  [ "$wt" != "$repo" ] && loc="$loc${DIM}[${R}${REPO}${wt}${R}${DIM}]${R}"

  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && loc="$loc${DIM}:${R}${BRANCH}${branch}${R}"
  [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ] && loc="$loc${RED}*${R}"

  if counts=$(git -C "$dir" rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null); then
    behind=${counts%%[[:space:]]*} ahead=${counts##*[[:space:]]}
    [ "$ahead" -gt 0 ] 2>/dev/null && loc="$loc ${YEL}↑$ahead${R}"
    [ "$behind" -gt 0 ] 2>/dev/null && loc="$loc ${YEL}↓$behind${R}"
  fi

  out="$out$SEP$loc"
else
  out="$out$SEP${REPO}$(basename "$dir")${R}"
fi

# La barre se remplit à mesure que la fenêtre de contexte est consommée.
if [ "$used" -ge 0 ] 2>/dev/null; then
  width=10
  filled=$(( (used * width + 50) / 100 ))
  if   [ "$used" -ge 85 ]; then c=$RED t=$RED_T
  elif [ "$used" -ge 60 ]; then c=$YEL t=$YEL_T
  else                         c=$GRN t=$GRN_T
  fi
  printf -v bar '%*s' "$filled" ''
  printf -v rest '%*s' "$((width - filled))" ''
  out="$out$SEP${c}${bar}${t}${rest}${R}"
fi

printf '%s%s%s$%.2f%s' "$out" "$SEP" "$DIM" "$cost" "$R"
