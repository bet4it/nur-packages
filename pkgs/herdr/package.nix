{
  lib,
  rustPlatform,
  fetchFromGitHub,
  callPackage,
  zig_0_15,
}:

let
  pname = "herdr";
  version = "0.4.11";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    rev = "v${version}";
    hash = "sha256-5VZBGe1v6MLdEtP5xEs6H3p2kwFBEQ9Tqkxd2LOxglc=";
  };

  zigDeps = callPackage "${src}/vendor/libghostty-vt/build.zig.zon.nix" {
    name = "${pname}-libghostty-vt-zig-deps-${version}";
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = "sha256-eYUdd/mZNxx/gT55Wk2gqVouYadvqisaMXOo1ZY+wok=";

  patches = [
    ./build-rs-use-system-zig-deps.patch
    ./detect-cmdline-agent-name.patch
  ];

  nativeBuildInputs = [ zig_0_15 ];

  LIBGHOSTTY_VT_ZIG_SYSTEM = zigDeps;

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
  '';

  # Some tests try to spawn processes (sleep, shell) which don't exist in the sandbox
  doCheck = false;

  meta = {
    description = "Terminal-native agent multiplexer for coding agents";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
  };
}
