{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  python3,
  pkg-config,
  libsecret,
  nodejs,
}:

let
  desktopItem = makeDesktopItem {
    name = "termix";
    exec = "termix %U";
    icon = "termix";
    desktopName = "Termix";
    comment = "A web-based server management platform with SSH terminal, tunneling, and file editing capabilities";
    categories = [
      "Development"
      "System"
      "TerminalEmulator"
    ];
  };
in
buildNpmPackage rec {
  pname = "termix";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "Termix-SSH";
    repo = "Termix";
    rev = "release-${version}-tag";
    hash = "sha256-3QyTXcNHGuk4JrNI/soMx4u8I3nlCvZdIjBrOcAiKBQ=";
  };

  npmDepsHash = "sha256-bmdubkApp/0lO5SLgDlkD3rAxMASuQ+NyuS3Nc3EcRY=";

  nativeBuildInputs = [
    makeWrapper
    python3
    pkg-config
    copyDesktopItems
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libsecret
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

  makeCacheWritable = true;

  postPatch = ''
        substituteInPlace src/backend/database/database.ts \
          --replace-fail '    cb(null, "uploads/");' '    cb(null, path.join(process.env.TERMIX_DATA_DIR || process.cwd(), "uploads"));' \
          --replace-fail '  const uploadsDir = path.join(process.cwd(), "uploads");' '  const uploadsDir = path.join(process.env.TERMIX_DATA_DIR || process.cwd(), "uploads");'

        substituteInPlace src/ui/main-axios.ts \
          --replace-fail '        if (config?.serverUrl) {' '        if (config?.serverUrl && !embeddedMode) {'

        substituteInPlace src/ui/desktop/authentication/Auth.tsx \
          --replace-fail '          if (status?.embedded && status?.running && !config?.serverUrl) {' '          if (status?.embedded && status?.running) {' \
          --replace-fail '            setCurrentServerUrl("");' '            setCurrentServerUrl("http://localhost:30001");'

        sed -i 's#const isDev = process.env.NODE_ENV === "development" || !app.isPackaged;#const isPackaged = process.env.TERMIX_IS_PACKAGED === "1" || app.isPackaged;\
    const isDev = process.env.NODE_ENV === "development" || !isPackaged;#' electron/main.cjs
        sed -i '/^const appRoot = isDev ? process.cwd() : path.join(__dirname, "..");$/a\
    \
    function getAppVersion() {\
      if (process.env.TERMIX_APP_VERSION) {\
        return process.env.TERMIX_APP_VERSION;\
      }\
      return app.getVersion();\
    }' electron/main.cjs
        sed -i '/cwd: appRoot,/a\
          execPath: process.env.TERMIX_NODE_EXECUTABLE || process.execPath,' electron/main.cjs
        substituteInPlace electron/main.cjs \
          --replace-fail 'trayIcon = path.join(appRoot, "public", "icons", "32x32.png");' 'trayIcon = path.join(appRoot, "public", "icon.png");' \
          --replace-fail 'const appVersion = app.getVersion();' 'const appVersion = getAppVersion();' \
          --replace-fail 'return app.getVersion();' 'return getAppVersion();' \
          --replace-fail 'const localVersion = app.getVersion();' 'const localVersion = getAppVersion();' \
          --replace-fail 'localVersion: app.getVersion(),' 'localVersion: getAppVersion(),'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/termix

    # Copy the built backend and frontend
    cp -r dist $out/share/termix/

    # Copy electron main process files
    cp -r electron $out/share/termix/

    # Preserve package metadata and public assets so Electron reports the app
    # version correctly and the tray/icon lookups resolve at runtime.
    cp package.json $out/share/termix/
    cp -r public $out/share/termix/

    # Copy node_modules
    cp -r node_modules $out/share/termix/

    # Install icon
    install -Dm644 public/icon.png $out/share/icons/hicolor/512x512/apps/termix.png

    makeWrapper ${lib.getExe electron} $out/bin/termix \
      --add-flags $out/share/termix/electron/main.cjs \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --run 'export TERMIX_DATA_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/Electron/server-data"' \
      --set TERMIX_APP_VERSION "${version}" \
      --set TERMIX_IS_PACKAGED 1 \
      --set TERMIX_NODE_EXECUTABLE "${lib.getExe nodejs}" \
      --inherit-argv0

    makeWrapper ${lib.getExe nodejs} $out/bin/termix-server \
      --add-flags "$out/share/termix/dist/backend/backend/starter.js" \
      --chdir "$out/share/termix" \
      --run 'export TERMIX_DATA_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/Electron/server-data"' \
      --set NODE_ENV production

    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = {
    description = "Web-based server management platform with SSH terminal, tunneling, and file editing capabilities";
    homepage = "https://github.com/Termix-SSH/Termix";
    license = lib.licenses.asl20;
    mainProgram = "termix";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
}
