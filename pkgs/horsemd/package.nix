{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:

let
  desktopItem = makeDesktopItem {
    name = "horsemd";
    exec = "horsemd %U";
    icon = "horsemd";
    desktopName = "HorseMD";
    comment = "A warm, Typora-style Markdown editor";
    categories = [
      "Development"
      "TextEditor"
    ];
    startupWMClass = "HorseMD";
  };
in
buildNpmPackage rec {
  pname = "horsemd";
  version = "0.13.29";

  src = fetchFromGitHub {
    owner = "BND-1";
    repo = "horseMD";
    rev = "v${version}";
    hash = "sha256-BD+8YYifdCYlc5orU2lUaDneLtxsMNoK71LumDfgnvI=";
  };

  npmDepsHash = "sha256-NGUaJDbfRMUcLmcnyjhiyGN2lw3ZtjDt+x9RAWmL6N4=";

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  npmBuildScript = "build";
  dontNpmInstall = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/horsemd $out/bin

    cp -r out $out/lib/horsemd/out
    cp package.json $out/lib/horsemd/package.json
    cp -r node_modules $out/lib/horsemd/node_modules
    cp -r build $out/lib/horsemd/build
    cp -r assets $out/lib/horsemd/assets

    makeWrapper ${lib.getExe electron} $out/bin/horsemd \
      --add-flags $out/lib/horsemd \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set-default ELECTRON_IS_DEV 0 \
      --inherit-argv0

    runHook postInstall
  '';

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [ desktopItem ];

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    for s in 16 24 32 48 64 128 256 512; do
      install -Dm644 build/icons/''${s}x''${s}.png \
        $out/share/icons/hicolor/''${s}x''${s}/apps/horsemd.png
    done
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/BND-1/horseMD"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "A warm, Typora-style Markdown editor";
    homepage = "https://github.com/BND-1/horseMD";
    license = lib.licenses.mit;
    mainProgram = "horsemd";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
