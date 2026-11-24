{ nixpkgs-unstable }:
final: prev:
let
  unstable = import nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  # TODO(26.11): check each entry still needs unstable once stable has caught up, including the
  # fresh-editor oniguruma workaround below.
  inherit (unstable)
    btop
    claude-code
    prek
    gh
    mise
    readeck # 0.23 : connexion OIDC (Authelia)
    ;

  # The unstable package sets RUSTONIG_SYSTEM_LIBONIG (link the system
  # oniguruma) but does not provide oniguruma itself, so onig_sys cannot
  # find it with pkg-config.
  fresh-editor = unstable.fresh-editor.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ unstable.oniguruma ];
  });
}
