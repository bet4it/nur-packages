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
  };
in
buildNpmPackage rec {
  pname = "electerm";
  version = "3.6.6";

  src = fetchFromGitHub {
    owner = "electerm";
    repo = "electerm";
    rev = "v${version}";
    hash = "sha256-3aSOLXEIkjyb09ZgGEsP01HqvLoYLRtaciYNH0dgRC0=";
  };

  npmDepsHash = "sha256-jXbmADqWYT9rdDgpU1mZ0U7lp3QIH8S6PtOH8N686cE=";

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

    # Generate html
    node build/bin/pug.js

    # Prepare production app (patched to skip npm install)
    node build/bin/prepare.js

    # Populate node_modules in work/app
    cp -r node_modules work/app/

    # Prune dev dependencies (optional, but good practice)
    # Since we don't have network, we rely on the fact that we copied everything.
    # We might want to remove some known dev deps if size is an issue.
    # For now, let's leave it as is.
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

    install -Dm644 work/app/assets/images/electerm.png $out/share/icons/hicolor/512x512/apps/electerm.png

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
