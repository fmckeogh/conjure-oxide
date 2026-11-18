{
  description = "A Nix Flake for Conjure Oxide development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    # Conjure built from source, with Savile Row, Minion and Chuffed on its PATH.
    # It keeps its own nixpkgs, so it is built against the one it is tested with.
    conjure.url = "github:fmckeogh/conjure/nix";
  };

  outputs = { self, nixpkgs, utils, rust-overlay, ... }@inputs:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };
        # The Rust toolchain rust-toolchain.toml pins, for both the package and the dev shell.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        conjure = inputs.conjure.packages.${system}.conjure;
        conjure-oxide = pkgs.callPackage ./package.nix {
          inherit conjure rustToolchain;
          # What `git describe` would report, for the `git_version!()` macros.
          gitVersion = self.shortRev or self.dirtyShortRev or "unknown";
        };
      in
      {
        packages = {
          inherit conjure-oxide;
          default = conjure-oxide;
        };

        devShells.default = import ./shell.nix { inherit pkgs conjure rustToolchain; };
      });
}
