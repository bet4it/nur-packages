{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm_10,
  nodejs,
  fetchPnpmDeps,
  electron_40,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  libglvnd,
  dpkg,
  fakeroot,
  pciutils,
  squashfsTools,
  fetchurl,
  patchelf,
  vulkan-loader,
}:

stdenv.mkDerivation rec {
  pname = "spacecake";
  version = "0.1.0-alpha.71";

  src = fetchFromGitHub {
    owner = "spacecake-labs";
    repo = "spacecake";
    rev = "v${version}";
    hash = "sha256-5jTbX1ounCEWPuXgo9yU0sS+elqTHiWEc6tU7aOIrNQ=";
  };

  sourceRoot = "source/spacecake-app";

  pnpmDeps = fetchPnpmDeps {
    inherit
      pname
      version
      src
      sourceRoot
      ;
    hash = "sha256-xFYnXsyZe2bAhTX/F5FJ7x9o5QaWQaGcTz9Gi/zK5Hw=";
    fetcherVersion = 3;
  };

  electronZip = fetchurl {
    url = "https://github.com/electron/electron/releases/download/v40.8.0/electron-v40.8.0-linux-x64.zip";
    hash = "sha256-V1OxAvOJxCHmtd94CYXXDA0SHG+6P8KB2r6jbvwMz+c=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10.configHook
    makeWrapper
    copyDesktopItems
    dpkg
    fakeroot
    squashfsTools
    patchelf
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
  };

  buildPhase = ''
        runHook preBuild

        # Create local electron cache for packager
        export ELECTRON_CACHE=$TMPDIR/electron_cache
        export electron_config_cache=$ELECTRON_CACHE
        mkdir -p $ELECTRON_CACHE
        cp $electronZip $ELECTRON_CACHE/electron-v40.8.0-linux-x64.zip

        # Fix postinstall script
        substituteInPlace package.json \
          --replace-fail 'node node_modules/@vscode/ripgrep/lib/postinstall.js' 'true'

        # Disable publishers that require network access
        substituteInPlace forge.config.ts \
          --replace-fail 'publishers: [' 'publishers: [], _oldPublishers: [' \
          --replace-fail 'name: "@reforged/maker-appimage"' 'name: "@reforged/maker-appimage-disabled"' \
          --replace-fail 'packagerConfig: {' "packagerConfig: { electronZipDir: process.env.ELECTRON_CACHE, "

        # Force packaged-mode semantics under the Nix wrapper. Upstream uses
        # app.isPackaged to switch code paths, but our generic Electron wrapper does
        # not set that the same way as an upstream bundle.
        sed -i 's#const isDev = process.env.NODE_ENV === "development" || !app.isPackaged#const isPackaged = process.env.SPACECAKE_IS_PACKAGED === "1" || app.isPackaged\
    const isDev = process.env.NODE_ENV === "development" || !isPackaged#' src/main.ts
        sed -i 's#if (!app.isPackaged) {#if (!isPackaged) {#' src/main.ts
        sed -i 's#if (!app.isPackaged && app.dock) {#if (!isPackaged \&\& app.dock) {#' src/main.ts

        sed -i 's#const { app } = require("electron")#const { app } = require("electron")\
        const forcedPackaged = process.env.SPACECAKE_IS_PACKAGED === "1"#' src/services/spacecake-home.ts
        sed -i 's#isPackaged: app.isPackaged,#isPackaged: forcedPackaged || app.isPackaged,#' src/services/spacecake-home.ts
        sed -i 's#cliSourceEntryPath: app.isPackaged ? "" : path.resolve(__dirname, "../../../cli/src/main.ts"),#cliSourceEntryPath: forcedPackaged || app.isPackaged ? "" : path.resolve(__dirname, "../../../cli/src/main.ts"),#' src/services/spacecake-home.ts

        sed -i 's#if (!app.isPackaged) {#const isPackaged = process.env.SPACECAKE_IS_PACKAGED === "1" || app.isPackaged\
      if (!isPackaged) {#' src/update.ts
        sed -i 's#  // Linux AppImage: use custom updater#  if (process.platform === "linux") {\
        console.log("[updater] Skipping self-update in Nix package")\
        return\
      }\
    \
      // Linux AppImage: use custom updater#' src/update.ts
        sed -i 's#  await fixPathPromise#  void fixPathPromise.catch(() => {})#' src/main.ts

        # Needs to bypass electron forge and build directly or build using pnpm
        pnpm run package --arch=x64

        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      $out/bin \
      $out/libexec/spacecake/resources \
      $out/libexec/spacecake/assets \
      $out/share/icons/hicolor/512x512/apps

    # Spacecake expects a packaged Electron layout and resolves bundled paths via
    # process.resourcesPath. Running the system electron wrapper directly against
    # app.asar breaks those assumptions and prevents the UI from initializing.
    cp -r ${electron_40}/libexec/electron/* $out/libexec/spacecake/
    cp -r out/spacecake-linux-x64/resources/* $out/libexec/spacecake/resources/
    cp assets/icon.png $out/libexec/spacecake/assets/icon.png
    cp assets/icon.png $out/share/icons/hicolor/512x512/apps/spacecake.png

    ln -s ../libexec/spacecake/resources $out/share/spacecake

    # Preserve Electron's own RUNPATH and only add libstdc++ for the Linux
    # native modules bundled in app.asar.unpacked.
    for nativeModule in \
      $out/libexec/spacecake/resources/app.asar.unpacked/node_modules/@lydell/node-pty-linux-x64/pty.node \
      $out/libexec/spacecake/resources/app.asar.unpacked/node_modules/@parcel/watcher-linux-x64-glibc/watcher.node \
      $out/libexec/spacecake/resources/app.asar.unpacked/node_modules/tree-sitter-python/prebuilds/linux-x64/tree-sitter-python.node
    do
      if [ -f "$nativeModule" ]; then
        chmod u+w "$nativeModule"
        patchelf \
          --add-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
          "$nativeModule"
      fi
    done

    makeWrapper $out/libexec/spacecake/electron $out/bin/spacecake \
      --run '
        for profileDir in "$HOME/.config/spacecake" "$HOME/.config/spacecake-dev"; do
          lockPath="$profileDir/SingletonLock"
          if [ ! -L "$lockPath" ]; then
            continue
          fi

          lockTarget="$(readlink "$lockPath" || true)"
          lockPid="$(printf "%s" "$lockTarget" | sed "s/^nixos-//")"

          case "$lockPid" in
            ""|*[!0-9]*)
              continue
              ;;
          esac

          if [ ! -e "/proc/$lockPid" ]; then
            rm -f \
              "$profileDir/SingletonLock" \
              "$profileDir/SingletonSocket" \
              "$profileDir/SingletonCookie"
          fi
        done
      ' \
      --chdir "$out/libexec/spacecake" \
      --set NODE_ENV production \
      --set SPACECAKE_IS_PACKAGED 1 \
      --set CHROME_DEVEL_SANDBOX "$out/libexec/spacecake/chrome-sandbox" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          libglvnd
          vulkan-loader
          pciutils
        ]
      }" \
      --add-flags "\''${WAYLAND_DISPLAY:+--ozone-platform=x11 --disable-gpu-compositing --disable-features=Vulkan --disable-vulkan}"
      
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "spacecake";
      exec = "spacecake %U";
      icon = "spacecake";
      desktopName = "Spacecake";
      comment = meta.description;
      categories = [
        "Development"
        "IDE"
      ];
      startupWMClass = "spacecake";
    })
  ];

  meta = {
    description = "An AI-native IDE";
    homepage = "https://github.com/spacecake-labs/spacecake";
    license = lib.licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "spacecake";
    platforms = lib.platforms.linux;
  };
}
