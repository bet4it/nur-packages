{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:

let
  desktopItem = makeDesktopItem {
    name = "colamd";
    exec = "colamd %U";
    icon = "colamd";
    desktopName = "ColaMD";
    comment = "A free, elegant Markdown editor for humans and AI agents";
    categories = [
      "Office"
      "TextEditor"
    ];
    startupWMClass = "ColaMD";
  };
in
buildNpmPackage rec {
  pname = "colamd";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "marswaveai";
    repo = "ColaMD";
    rev = "47e94ffba3588eab2d703107363d743880983e29";
    hash = "sha256-+4rM9lH5H4posV6Vmu5uFhoQZH6YMzgTkFbCB6YRkYE=";
  };

  npmDepsHash = "sha256-xYgFWXcBfnmJDlXIopCyKjf6ibQr2MkyEbgbcLBc2UM=";

  patches = [
    ./use-app-resources.patch
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  npmBuildScript = "build";
  dontNpmInstall = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/colamd/resources

    cp -r dist $out/lib/colamd/dist
    cp package.json $out/lib/colamd/package.json

    # Bundled demos and templates loaded at runtime from __dirname
    cp -r resources/templates $out/lib/colamd/resources/templates
    cp -r resources/demo $out/lib/colamd/resources/demo

    makeWrapper ${lib.getExe electron} $out/bin/colamd \
      --add-flags $out/lib/colamd \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0

    runHook postInstall
  '';

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [ desktopItem ];

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm644 resources/icon.png $out/share/icons/hicolor/512x512/apps/colamd.png
  '';

  meta = {
    description = "A free, elegant Markdown editor for humans and AI agents";
    homepage = "https://github.com/marswaveai/ColaMD";
    license = lib.licenses.mit;
    mainProgram = "colamd";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
