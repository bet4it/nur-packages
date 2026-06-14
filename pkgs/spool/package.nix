{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  libcap,
  libglvnd,
  openssl,
  patchelf,
  pnpm_10,
  pnpmConfigHook,
  electron,
  nodejs_22,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  pkg-config,
  xdg-terminal-exec,
  xz,
  zlib,
  callPackage,
  writableTmpDirAsHomeHook,
}:

let
  pname = "spool";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "spool-lab";
    repo = "spool";
    rev = "v${version}";
    hash = "sha256-cCf7qTv4EJhHh5SF7HnjryjWY+LHVab09k3wk5uOCvc=";
  };

  acpCodexLibPath = lib.makeLibraryPath [
    libcap
    openssl
    stdenv.cc.cc.lib
    stdenv.cc.libc
    xz
    zlib
  ];

  electronRuntimeLibPath = lib.makeLibraryPath [
    libglvnd
  ];

  runtimePath = lib.makeBinPath [
    xdg-terminal-exec
  ];

  desktopItem = makeDesktopItem {
    name = "spool";
    exec = "spool %U";
    icon = "spool";
    desktopName = "Spool";
    comment = "Desktop app for searching and sharing AI coding sessions";
    categories = [
      "Development"
      "Utility"
    ];
    startupWMClass = "Spool";
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_10;
    pnpmWorkspaces = [
      "@spool/app"
      "@spool-lab/core"
      "@spool-lab/redact"
      "@spool/share-kit"
    ];
    postPatch = ''
      cp ${./packages/app/package.json} packages/app/package.json
      cp ${./packages/core/package.json} packages/core/package.json
      cp ${./pnpm-lock.yaml} pnpm-lock.yaml
    '';
    fetcherVersion = 3;
    hash = "sha256-g2JPb7IHclcqwNjkgR5S1dmhW8ek+Dy/3l1BxbUciqU=";
  };

  pnpmWorkspaces = [
    "@spool/app"
    "@spool-lab/core"
    "@spool-lab/redact"
    "@spool/share-kit"
  ];

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    nodejs_22
    patchelf
    pkg-config
    pnpm_10
    pnpmConfigHook
    python3
    writableTmpDirAsHomeHook
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    npm_config_build_from_source = "true";
    npm_config_fallback_to_build = "true";
  };

  dontNpmInstall = true;

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"packageManager": "pnpm@10.33.0"' '"packageManager": "pnpm@${pnpm_10.version}"'

    cp ${./packages/app/package.json} packages/app/package.json
    cp ${./packages/core/package.json} packages/core/package.json
    cp ${./pnpm-lock.yaml} pnpm-lock.yaml
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    export npm_config_nodedir=${electron.headers}
    export npm_config_target=${electron.version}
    export npm_config_runtime=electron
    export npm_config_disturl=https://electronjs.org/headers
    export npm_config_manage_package_manager_versions=false
    export COREPACK_ENABLE_PROJECT_SPEC=0

    for betterSqlite in $(find . -path '*/node_modules/better-sqlite3' -type d); do
      (
        cd "$betterSqlite"
        npm run build-release --offline --nodedir=${electron.headers}
        rm -rf build/Release/{.deps,obj,obj.target,test_extension.node}
      )
    done

    pnpm --filter @spool/app run build:electron
    pnpm --filter @spool/app exec electron-builder \
      --dir \
      --linux \
      --publish never \
      -c.asar=false \
      -c.electronDist=${electron.dist} \
      -c.electronVersion=${electron.version} \
      -c.npmRebuild=false

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/spool $out/bin
    cp -R packages/app/dist/linux-unpacked/. $out/share/spool/

    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${acpCodexLibPath}" \
      $out/share/spool/resources/app/node_modules/acp-extension-codex-linux-x64/bin/acp-extension-codex

    appExe=$out/share/spool/@spoolapp

    makeWrapper "$appExe" $out/bin/spool \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --prefix PATH : "${runtimePath}" \
      --prefix LD_LIBRARY_PATH : "${electronRuntimeLibPath}" \
      --inherit-argv0

    install -Dm644 packages/app/resources/icon.png $out/share/icons/hicolor/512x512/apps/spool.png

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  passthru.updateScript = lib.getExe (callPackage ./update.nix { });

  meta = {
    description = "Desktop app for searching and sharing AI coding sessions";
    homepage = "https://github.com/spool-lab/spool";
    changelog = "https://github.com/spool-lab/spool/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "spool";
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
}
