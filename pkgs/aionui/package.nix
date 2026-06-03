{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  bun,
  electron,
  nodejs_22,
  python3,
  pkg-config,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  writableTmpDirAsHomeHook,
  aioncore,
}:

let
  commonEnv = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  desktopItem = makeDesktopItem {
    name = "aionui";
    desktopName = "AionUi";
    exec = "aionui %U";
    icon = "aionui";
    comment = "Modern AI chat interface for command-line agents";
    categories = [
      "Office"
      "Utility"
    ];
    mimeTypes = [ "x-scheme-handler/aionui" ];
    startupWMClass = "AionUi";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aionui";
  version = "2.1.10";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionUi";
    rev = "v${finalAttrs.version}";
    hash = "sha256-8DDW2TFhje0sDK8LphdR1wGLDr8nhwxEP5YvTnnkndQ=";
  };

  node_modules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      pkg-config
      python3
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;
    dontPatchShebangs = true;

    env = commonEnv;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -prune -exec cp -R --parents {} $out \;

      runHook postInstall
    '';

    outputHash = "sha256-03ar0rUH70uIfK46cj1g/A5IicKFJg2pY0iRvEOXYwA=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    copyDesktopItems
    makeWrapper
    nodejs_22
    pkg-config
    python3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  env = commonEnv // {
    NODE_ENV = "production";
    CI = "1";
  };

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .
    find . -type d -name node_modules -exec chmod -R u+rw {} +
    ln -sfn .bun/node_modules/serve-handler node_modules/serve-handler
    find . -path "*/node_modules/.bin" -type d -exec chmod -R u+x {} +
    patchShebangs .

    export HOME="$TMPDIR"
    export PATH="$PWD/node_modules/.bin:$PATH"

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    bunx electron-vite build --config packages/desktop/electron.vite.config.ts
    node scripts/build-mcp-servers.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appRoot="$out/lib/aionui"
    mkdir -p "$appRoot" "$out/bin" "$out/share/pixmaps"

    cp -R out packages public package.json node_modules "$appRoot"/
    mkdir -p "$appRoot/resources"
    cp resources/app.png "$appRoot/resources/app.png"

    install -Dm444 resources/app.png "$out/share/pixmaps/aionui.png"
    install -Dm444 resources/app.png "$out/share/icons/hicolor/512x512/apps/aionui.png"

    makeWrapper ${lib.getExe electron} "$out/bin/aionui" \
      --chdir "$appRoot" \
      --add-flags "$appRoot" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --prefix PATH : ${
        lib.makeBinPath [
          aioncore
          nodejs_22
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} \
      --set-default ELECTRON_IS_DEV 0 \
      --set-default NODE_ENV production \
      --inherit-argv0

    copyDesktopItems

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  passthru = {
    inherit aioncore;
    inherit (finalAttrs) node_modules;

    updateScript = nix-update-script {
      attrPath = "aionui";
      extraArgs = [
        "--flake"
        "--subpackage"
        "node_modules"
        "--url=https://github.com/iOfficeAI/AionUi"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Modern AI chat interface for command-line agents";
    homepage = "https://github.com/iOfficeAI/AionUi";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "aionui";
    platforms = lib.platforms.linux;
  };
})
