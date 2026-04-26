{
  lib,
  rustPlatform,
  fetchFromGitHub,
  callPackage,
  zig_0_15,
}:

let
  pname = "herdr";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    rev = "v${version}";
    hash = "sha256-gI3VY9qwGFFoNEUIprZqa6ctQogRTjUsG4QcWGAokbs=";
  };

  zigDeps = callPackage ./build.zig.zon.nix {
    name = "${pname}-libghostty-vt-zig-deps-${version}";
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = "sha256-e5OyXINaTSena/1RF9yeX4Zw6rn6ZX6AGMB6SN+yn3Q=";

  patches = [
    ./build-rs-use-system-zig-deps.patch
    ./detect-cmdline-agent-name.patch
  ];

  nativeBuildInputs = [ zig_0_15 ];

  dontUseZigBuild = true;
  dontUseZigInstall = true;

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
