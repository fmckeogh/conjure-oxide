# flake.nix passes in `conjure` from the conjure flake, which brings Savile Row, Minion and Chuffed with it,
# and `rustToolchain`, the Rust toolchain rust-toolchain.toml pins.
{ pkgs ? import <nixpkgs> {}, conjure, rustToolchain }:
let

    # The pinned toolchain, plus the standard library's source and rust-analyzer for editors.
    devToolchain = rustToolchain.override (old: {
        extensions = (old.extensions or []) ++ [ "rust-src" "rust-analyzer" ];
    });

    clangMkShell = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; };

    # Dependencies for development that are not system packages, but still required for development (eg; z3 and JDK)
    DevDependencies = with pkgs; [
        python3
        jre
        z3
        pkgs.mdbook
        git
        gh
    ];

    # System libraries go here (e.g. openssl, pkg-config)
    MedievalDependencies = with pkgs; [
        clang-tools
        libclang
        llvmPackages.libclang
        pkg-config
        openssl
    ];

    # rust-specific dependencies
    RustDependencies = [
        devToolchain
        pkgs.cargo-nextest
    ];
in

clangMkShell {
    buildInputs = [ conjure ] ++ MedievalDependencies ++ DevDependencies ++ RustDependencies;

    # Fixes rust-analyzer looking for standard library source code
    RUST_SRC_PATH = "${devToolchain}/lib/rustlib/src/rust/library";
    LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib";

    shellHook = ''
      export PATH="${pkgs.clangStdenv.cc}/bin:$PATH";
    '';
}
