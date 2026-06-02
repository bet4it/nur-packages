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
  version = "1.1.20";

  src = fetchFromGitHub {
    owner = "binaricat";
    repo = "Netcatty";
    rev = "v${version}";
    hash = "sha256-bqp0W4GWWRAhf+U5hwlxBRgzJKJs29J3h/uW+oI5lQA=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-ybcxDej/ASMhvk810iURJBok/hNQjRg7MUwNbXkTgMo=";

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
    npm_config_nodedir = nodejs_22;
  };

  makeCacheWritable = true;

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"version": "0.0.0"' '"version": "${version}"'
  '';

  preBuild = ''
    patch -p1 < patches/ssh2+1.17.0.patch
    npm rebuild node-pty @serialport/bindings-cpp --build-from-source
  '';

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    mkdir -p $out/share/netcatty
    cp -r dist electron lib public skills package.json node_modules $out/share/netcatty/
    find $out/share/netcatty/node_modules -type d -name .bin -prune -exec rm -rf {} +
    find $out/share/netcatty/node_modules -xtype l -delete

    install -Dm644 build/icons/512x512.png $out/share/icons/hicolor/512x512/apps/netcatty.png

    makeWrapper ${lib.getExe electron} $out/bin/netcatty \
      --add-flags $out/share/netcatty \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --chdir $out/share/netcatty \
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
