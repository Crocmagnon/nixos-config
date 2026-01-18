{ nixpkgs-unstable }:
final: prev: {
  inherit
    (import nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    })
    btop
    ;
}
