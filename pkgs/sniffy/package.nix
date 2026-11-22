{
  lib,
  stdenv,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs_22,
  pkg-config,
  wrapGAppsHook4,
  copyDesktopItems,
  makeDesktopItem,
  gtk4,
  webkitgtk_6_0,
  libsoup_3,
  glib,
  libx11,
  nix-update-script,
}:

let
  pname = "sniffy";
  version = "0.1.0-beta.7";

  src = fetchFromGitHub {
    owner = "mintfog";
    repo = "sniffy";
    tag = "v${version}";
    hash = "sha256-LUG38VpdsrPOP67HsLiDmnuLAF9/hvpMc0Zl6tTsL+Y=";
  };

  sniffy-web = buildNpmPackage {
    pname = "sniffy-web";
    inherit version src;

    npmDeps = fetchNpmDeps {
      inherit src;
      sourceRoot = "${src.name}/web";
      hash = "sha256-QbeLICgGeOvxeUyq6UDhaOQzhSEDzzebHYx8NzLSlvU=";
    };

    postPatch = ''
      cd web
    '';

    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "sniffy";
    desktopName = "Sniffy";
    exec = "sniffy-desktop";
    icon = "sniffy";
    comment = "Cross-platform network capture and debugging tool";
    categories = [
      "Development"
      "Network"
    ];
    startupNotify = true;
    startupWMClass = "sniffy";
  };
in
buildGoModule rec {
  inherit pname version src;

  vendorHash = "sha256-sM32LYO4J8o8mGm+5O4yiE/1oOADpfzef0Mg7FAhAUM=";

  subPackages = [
    "cmd/sniffy"
    "cmd/sniffy-desktop"
  ];

  tags = [
    "desktop"
    "production"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/mintfog/sniffy/internal/version.Version=v${version}"
  ];

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
    copyDesktopItems
  ];

  buildInputs = [
    gtk4
    webkitgtk_6_0
    libsoup_3
    glib
    libx11
  ];

  env.CGO_ENABLED = 1;

  preBuild = ''
    rm -rf cmd/sniffy-desktop/dist
    mkdir -p cmd/sniffy-desktop/dist
    cp -r ${sniffy-web}/* cmd/sniffy-desktop/dist/
  '';

  desktopItems = [ desktopItem ];

  postInstall = ''
    install -Dm644 build/appicon.png $out/share/icons/hicolor/1024x1024/apps/sniffy.png
    install -Dm644 build/appicon.png $out/share/pixmaps/sniffy.png
  '';

  passthru = {
    web = sniffy-web;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=web.npmDeps"
        "--url=https://github.com/mintfog/sniffy"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Cross-platform network capture and debugging tool";
    homepage = "https://gosniffy.com";
    changelog = "https://github.com/mintfog/sniffy/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "sniffy-desktop";
    platforms = lib.platforms.linux;
  };
}
