{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nix-update-script,
  electron_40,
  nodejs_22,
  python3,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  libuv,
}:

let
  version = "0.1.69";

  rawSrc = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "v${version}";
    hash = "sha256-l4/iiwPQloF+WQZkj8V2jEBNuoyMAqK6Y6sFJ/MT7yY=";
  };

  npmDeps = fetchNpmDeps {
    name = "paseo-desktop-${version}-npm-deps";
    src = rawSrc;
    hash = "sha256-rjzmIH918poK05edU/f6G3iiP16Ra7g7vM0k5HbfKRs=";
  };
in
buildNpmPackage rec {
  pname = "paseo-desktop";
  inherit version npmDeps;

  src = rawSrc;

  nodejs = nodejs_22;

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    python3
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libuv
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    EXPO_NO_TELEMETRY = "1";
    CI = "1";
  };

  dontNpmBuild = true;

  postPatch = ''
    substituteInPlace packages/desktop/src/main.ts \
      --replace-fail 'if (!app.isPackaged) {' 'if (!app.isPackaged && process.env.PASEO_DESKTOP_USE_DEV_SERVER === "1") {'
  '';

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    npm rebuild node-pty
    npm run build:daemon
    npm run build:web --workspace=@getpaseo/app
    npm run build:main --workspace=@getpaseo/desktop

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appRoot="$out/lib/paseo-desktop"
    mkdir -p "$appRoot/packages" "$out/bin" "$out/share/pixmaps"

    cp package.json "$appRoot/"
    cp -a node_modules "$appRoot/"

    copy_package() {
      local name="$1"
      mkdir -p "$appRoot/packages/$name"
      cp "packages/$name/package.json" "$appRoot/packages/$name/"
      for dir in dist build assets bin node_modules; do
        if [ -d "packages/$name/$dir" ]; then
          cp -a "packages/$name/$dir" "$appRoot/packages/$name/"
        fi
      done
      for file in .env.example README.md; do
        if [ -f "packages/$name/$file" ]; then
          cp "packages/$name/$file" "$appRoot/packages/$name/"
        fi
      done
    }

    for name in highlight expo-two-way-audio relay server cli app desktop website; do
      copy_package "$name"
    done

    if [ -d skills ]; then
      cp -a skills "$appRoot/"
    fi

    install -m 444 packages/desktop/assets/icon.png "$out/share/pixmaps/paseo.png"

    makeWrapper ${electron_40}/bin/electron "$out/bin/paseo-desktop" \
      --add-flags "--no-sandbox" \
      --add-flags "$appRoot/packages/desktop" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "paseo";
      desktopName = "Paseo";
      exec = "paseo-desktop %U";
      icon = "paseo";
      comment = "Desktop GUI for Paseo";
      categories = [ "Development" ];
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/getpaseo/paseo"
      "--use-github-releases"
      "--version-regex=^v([0-9]+\\.[0-9]+\\.[0-9]+)$"
    ];
  };

  meta = {
    description = "Desktop GUI for Paseo, a self-hosted app for AI coding agents";
    homepage = "https://github.com/getpaseo/paseo";
    license = lib.licenses.agpl3Plus;
    mainProgram = "paseo-desktop";
    platforms = lib.platforms.linux;
  };
}
