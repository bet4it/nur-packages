{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_10,
  nodejs_24,
  python3,
  pkg-config,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  patchelf,
  electron_41,
  libglvnd,
  pciutils,
  vulkan-loader,
}:

let
  pnpm = pnpm_10.override {
    nodejs = nodejs_24;
  };
in
stdenv.mkDerivation rec {
  pname = "orca";
  version = "1.3.48";

  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    rev = "v${version}";
    hash = "sha256-s/bE2Ug3iJVpEojX0OP0jGhCvVhpskghvZViFkyahoQ=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src pnpm;
    hash = "sha256-ovPd9HhEIRjtsI4a10sBVVcDy2oe+WTfh0vPIRYhTvg=";
    fetcherVersion = 3;
  };

  nativeBuildInputs = [
    nodejs_24
    pnpm
    pnpm.configHook
    python3
    pkg-config
    makeWrapper
    copyDesktopItems
    patchelf
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  env = {
    CI = true;
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
    COREPACK_ENABLE_PROJECT_SPEC = 0;
    npm_config_build_from_source = true;
    npm_config_nodedir = "${nodejs_24}";
    pnpm_config_manage_package_manager_versions = false;
  };

  preConfigure = ''
    export HOME=$TMPDIR
  '';

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"packageManager": "pnpm@10.24.0+sha512.01ff8ae71b4419903b65c60fb2dc9d34cf8bb6e06d03bde112ef38f7a34d6904c424ba66bea5cdcf12890230bf39f9580473140ed9c946fef328b6e5238a345a"' '"packageManager": "pnpm@${pnpm.version}"' \
      --replace-fail '"build:cli": "tsc -p config/tsconfig.cli.json --outDir out --composite false --incremental false && node config/scripts/install-dev-cli.mjs"' '"build:cli": "tsc -p config/tsconfig.cli.json --outDir out --composite false --incremental false"'

    substituteInPlace config/electron-builder.config.cjs \
      --replace-fail "productName: 'Orca'," "productName: 'Orca',
  electronDist: process.env.ELECTRON_DIST,
  electronVersion: process.env.ELECTRON_VERSION," \
      --replace-fail "npmRebuild: true" "npmRebuild: false"
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR

    pnpm rebuild electron esbuild

    npm_config_runtime=electron \
    npm_config_target=${electron_41.version} \
    npm_config_nodedir=${electron_41.headers} \
    pnpm rebuild \
      @parcel/watcher \
      better-sqlite3 \
      cpu-features \
      node-pty

    pnpm run build:release

    export ELECTRON_DIST=${electron_41.dist}
    export ELECTRON_VERSION=${electron_41.version}

    pnpm exec electron-builder --config config/electron-builder.config.cjs --dir --linux --publish never

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/libexec/orca" \
      "$out/share/icons/hicolor/256x256/apps"

    cp -r ${electron_41}/libexec/electron/* "$out/libexec/orca/"
    chmod -R u+w "$out/libexec/orca"
    cp -r dist/linux-unpacked/resources "$out/libexec/orca/"

    chmod -R u+w "$out/libexec/orca/resources"

    substituteInPlace "$out/libexec/orca/resources/bin/orca" \
      --replace-fail 'if [ -x "$APP_DIR/orca" ]; then' 'if [ -x "$APP_DIR/electron" ]; then
	ELECTRON="$APP_DIR/electron"
elif [ -x "$APP_DIR/orca" ]; then'

    while IFS= read -r nativeModule; do
      chmod u+w "$nativeModule"
      if patchelf --print-rpath "$nativeModule" >/dev/null 2>&1; then
        patchelf \
          --add-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
          "$nativeModule"
      fi
    done < <(find "$out/libexec/orca/resources/app.asar.unpacked" -type f -name '*.node')

    find "$out/libexec/orca/resources/app.asar.unpacked" -type f -name spawn-helper -exec chmod +x {} +
    chmod +x "$out/libexec/orca/resources/bin/orca"

    install -Dm644 resources/icon.png "$out/share/icons/hicolor/256x256/apps/orca.png"

    makeWrapper "$out/libexec/orca/electron" "$out/bin/orca" \
      --chdir "$out/libexec/orca" \
      --set NODE_ENV production \
      --set CHROME_DEVEL_SANDBOX "$out/libexec/orca/chrome-sandbox" \
      --add-flags "--class=orca" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          libglvnd
          vulkan-loader
          pciutils
        ]
      }" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    makeWrapper "$out/libexec/orca/resources/bin/orca" "$out/bin/orca-cli"

    copyDesktopItems

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "orca";
      exec = "orca %U";
      icon = "orca";
      desktopName = "Orca";
      comment = meta.description;
      categories = [
        "Development"
        "IDE"
      ];
      startupWMClass = "orca";
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Next-gen IDE for parallel agentic development";
    homepage = "https://github.com/stablyai/orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "orca";
    platforms = [ "x86_64-linux" ];
  };
}
