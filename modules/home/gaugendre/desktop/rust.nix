{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    clang
    cargo-watch
    cargo-audit
    cargo-binstall
  ];
  home.sessionPath = [
    "\${CARGO_HOME:-$HOME/.cargo}/bin"
  ];
  programs.helix.languages.language-server = {
    rust-analyzer.config = {
      check.command = "clippy";
      # cargo.features = "all";
    };
  };
}
