{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron_40,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  pkg-config,
  libsecret,
}:

let
  desktopItem = makeDesktopItem {
    name = "electerm";
    exec = "electerm %U";
    icon = "electerm";
    desktopName = "Electerm";
    comment = "Terminal/ssh/telnet/serialport/sftp client";
    categories = [
      "Development"
      "System"
      "TerminalEmulator"
    ];
    startupWMClass = "electerm";
  };
in
buildNpmPackage rec {
  pname = "electerm";
  version = "3.10.0";

  src = fetchFromGitHub {
    owner = "electerm";
    repo = "electerm";
    rev = "v${version}";
    hash = "sha256-AtW344CFCWiAh6hGy4bsKKLHQ2XVNCEzM3eOgJYK3yU=";
  };

  npmDepsHash = "sha256-rDYglqQvOe4SI6W3d1BWIRdNQ+pYbQheIwBwK4j9d6A=";

  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];

  nativeBuildInputs = [
    makeWrapper
    python3
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    copyDesktopItems
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libsecret
  ];

  patches = [
    ./no-npm-install-in-prepare.patch
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

  makeCacheWritable = true;

  postBuild = ''
    # Patch electron-log to avoid crash on null paths
    sed -i "s/return path.join(getAppData(platform), appName);/return path.join(getAppData(platform) || \"\", appName || \"\");/g" node_modules/electron-log/src/transports/file/variables.js

    # Rebuild native modules
    npm rebuild --build-from-source

    # Build frontend
    npm run vite-build

    # Copy assets
    node build/bin/copy.js
    cp node_modules/@electerm/electerm-resource/res/imgs/electerm-round-128x128.png \
      work/app/assets/images/electerm-round-128x128.png

    # Generate html
    node build/bin/pug.js

    # Prepare production app (patched to skip npm install)
    node build/bin/prepare.js

    node <<'EOF'
    const fs = require("fs");
    const path = require("path");

    const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
    const names = new Set([
      ...Object.keys(pkg.devDependencies || {}),
      "7zip-bin",
      "app-builder-bin",
      "app-builder-lib",
      "builder-util",
      "dmg-builder",
      "electron-publish",
      "postject",
    ]);

    for (const name of names) {
      const target = path.join("node_modules", ...name.split("/"));
      fs.rmSync(target, { recursive: true, force: true });
    }
    EOF

    # Populate node_modules in work/app
    cp -r node_modules work/app/
    find work/app/node_modules -type d -name .bin -prune -exec rm -rf {} +
    find work/app/node_modules -xtype l -delete
  '';

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/electerm
    cp -r work/app/* $out/share/electerm

    makeWrapper ${lib.getExe electron_40} $out/bin/electerm \
      --add-flags $out/share/electerm/app.js \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0

    install -Dm644 work/app/assets/images/electerm-round-128x128.png $out/share/icons/hicolor/128x128/apps/electerm.png

    copyDesktopItems

    runHook postInstall
  '';

  meta = {
    description = "Terminal/ssh/telnet/serialport/sftp client";
    homepage = "https://electerm.html5beta.com";
    license = lib.licenses.mit;
    mainProgram = "electerm";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
}
