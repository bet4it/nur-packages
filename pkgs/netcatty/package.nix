{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  nodejs_22,
  python3,
  pkg-config,
  libsecret,
}:

let
  desktopItem = makeDesktopItem {
    name = "netcatty";
    exec = "netcatty %U";
    icon = "netcatty";
    desktopName = "Netcatty";
    comment = "Modern SSH manager and terminal app";
    categories = [
      "Development"
      "System"
      "TerminalEmulator"
    ];
  };
in
buildNpmPackage rec {
  pname = "netcatty";
  version = "1.1.81";

  src = fetchFromGitHub {
    owner = "binaricat";
    repo = "Netcatty";
    rev = "v${version}";
    hash = "sha256-lBde4RZo1iDXyFLZfYRgF7vHvL9XfOslVpxBcXyerYw=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-LtuhefsTAgpYxnb+EXMikFH/SH8w7bMi8ubeCc65JNM=";

  npmFlags = [
    "--ignore-scripts"
  ];

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    python3
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libsecret
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
    npm_config_nodedir = electron.headers;
    npm_config_build_from_source = true;
  };

  makeCacheWritable = true;

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"version": "0.0.0"' '"version": "${version}"'

    # beforePackCursorSdk tries to npm install platform-specific @cursor/sdk
    # packages at build time, which fails in the Nix sandbox (no network).
    # afterPackMacUuid is macOS-only (no-op on Linux). Both are unnecessary.
    substituteInPlace electron-builder.config.cjs \
      --replace-fail "beforePack: './scripts/beforePackCursorSdk.cjs'," "" \
      --replace-fail "afterPack: './scripts/afterPackMacUuid.cjs'," ""
  '';

  preBuild = ''
    patch -p1 < patches/ssh2+1.17.0.patch
    node scripts/patch-xterm-webgl-atlas.cjs
    npm rebuild node-pty @serialport/bindings-cpp --build-from-source
  '';

  buildPhase = ''
    runHook preBuild

    npm run build

    npm exec electron-builder -- \
      --config electron-builder.config.cjs \
      --dir \
      --linux \
      --publish never \
      -c.electronDist=${electron.dist} \
      -c.electronVersion=${electron.version} \
      -c.npmRebuild=false

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/netcatty
    cp -r release/linux-unpacked/{locales,resources{,.pak}} $out/share/netcatty/

    install -Dm644 build/icons/512x512.png $out/share/icons/hicolor/512x512/apps/netcatty.png

    makeWrapper ${lib.getExe electron} $out/bin/netcatty \
      --add-flags $out/share/netcatty/resources/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_IS_DEV 0 \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set NODE_ENV production \
      --inherit-argv0

    copyDesktopItems

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = {
    description = "Modern SSH manager and terminal app with host grouping, SFTP, keychain, port forwarding, and a rich UI";
    homepage = "https://github.com/binaricat/Netcatty";
    changelog = "https://github.com/binaricat/Netcatty/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "netcatty";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
}
