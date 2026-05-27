{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    clang
    cargo-watch
    cargo-audit
    cargo-binstall
    jetbrains.rust-rover
  ];
  home.sessionPath = [
    "\${CARGO_HOME:-$HOME/.cargo}/bin"
  ];
  programs.fish.functions = {
    rustrover-here = "_here rust-rover";
  };
  programs.helix.languages.language-server = {
    rust-analyzer.config = {
      check.command = "clippy";
      # cargo.features = "all";
    };
  };
}
