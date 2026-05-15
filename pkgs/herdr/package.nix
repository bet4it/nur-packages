{
  _experimental-update-script-combinators,
  lib,
  fetchFromGitHub,
  callPackage,
  nix-update-script,
  runCommand,
  rustPlatform,
  zig_0_15,
}:

let
  pname = "herdr";
  version = "0.5.8";

  src = fetchFromGitHub {
    owner = "ogulcancelik";
    repo = "herdr";
    rev = "v${version}";
    hash = "sha256-nmFDcMmMhiklERIY2oPYqWqCPSzRWneHLawVtaxBZp0=";
  };

  zigDeps = callPackage ./build.zig.zon.nix {
    name = "${pname}-libghostty-vt-zig-deps-${version}";
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoHash = "sha256-nU69jhqx0HkybH9UnTyJfYQ3JOe2dluUSNfXvO++G7M=";

  patches = [
    ./build-rs-use-system-zig-deps.patch
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

  passthru = {
    zigDepsSource = runCommand "herdr-build.zig.zon.nix" { inherit src; } ''
      cp --no-preserve=all "$src/vendor/libghostty-vt/build.zig.zon.nix" "$out"
    '';

    updateScript = _experimental-update-script-combinators.sequence [
      (nix-update-script {
        extraArgs = [
          "--use-github-releases"
          "--version-regex=^v(.*)$"
        ];
      })
      {
        command = [
          "sh"
          "-ec"
          ''cp --no-preserve=all "$(nix-build -A herdr.zigDepsSource)" pkgs/herdr/build.zig.zon.nix''
        ];
        supportedFeatures = [ ];
      }
    ];
  };

  meta = {
    description = "Terminal-native agent multiplexer for coding agents";
    homepage = "https://github.com/ogulcancelik/herdr";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
  };
}
