# conjure-oxide. flake.nix passes in `conjure` from the conjure flake, `rustToolchain` (the Rust
# toolchain rust-toolchain.toml pins), and `gitVersion` for the `git_version!()` macros.
{
  lib,
  makeRustPlatform,
  clangStdenv,
  makeWrapper,
  pkg-config,
  writeShellScriptBin,
  z3,
  conjure,
  rustToolchain,
  gitVersion,
}:
let
  rustPlatform = makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };

  # `git_version!()` runs `git -C <crate> describe` while compiling, but the sandbox has no .git
  # directory, so this stand-in answers with `gitVersion` instead.
  gitStub = writeShellScriptBin "git" ''
    if [ "$1" = -C ]; then shift 2; fi
    case "$1" in
      describe) echo ${lib.escapeShellArg gitVersion} ;;
      rev-parse) echo .git ;;
      *) exit 1 ;;
    esac
  '';
in

# Built with Clang, like the dev shell.
(rustPlatform.buildRustPackage.override { stdenv = clangStdenv; }) {
  pname = "conjure-oxide";
  version = (lib.importTOML ./crates/conjure-cp-cli/Cargo.toml).package.version;

  # Just the Cargo workspace, so edits to docs/ or the Nix files don't trigger a rebuild.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./.cargo
      ./Cargo.lock
      ./Cargo.toml
      ./crates
      ./fuzz
      ./test-suite
    ];
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    # One hash for each git revision in Cargo.lock.
    outputHashes = {
      "tree-sitter-0.28.0" = "sha256-kNFE6y8g0dpprkUAbDjVb+vAeqP1dwbMH5DXnTFCYIQ=";
      "uniplate-0.4.6" = "sha256-QL+Zd+LKbPr/KVtSFxIxeHk5wNJHtCQMsjA1HVluw8U=";
    };
  };

  # What `make build-release` builds, with the default features.
  cargoBuildFlags = [
    "--package"
    "conjure-cp-cli"
    "--bin"
    "conjure-oxide"
  ];

  nativeBuildInputs = [
    gitStub
    makeWrapper
    pkg-config # z3-sys finds Z3 with it
    rustPlatform.bindgenHook # minion-sys and rustsat-cadical run bindgen
  ];
  buildInputs = [ z3 ];

  # Tests are left to CI and `make test`, where the integration suite cross-checks against
  # `conjure solve`.
  doCheck = false;

  # Some commands, such as test-solve, run `conjure`. Prefixing PATH keeps ImageMagick's
  # `conjure` from being picked up instead.
  postInstall = ''
    wrapProgram $out/bin/conjure-oxide --prefix PATH : ${lib.makeBinPath [ conjure ]}
  '';

  meta = {
    description = "Automated constraint modelling toolkit";
    homepage = "https://github.com/conjure-cp/conjure-oxide";
    license = lib.licenses.mpl20;
    mainProgram = "conjure-oxide";
  };
}
