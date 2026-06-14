{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  fetchNpmDeps,
  npmHooks,
  nodejs_22,
  pkg-config,
  wrapGAppsHook4,
  at-spi2-atk,
  cairo,
  gdk-pixbuf,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  hicolor-icon-theme,
  libayatana-appindicator,
  librsvg,
  libsoup_3,
  openssl,
  pango,
  webkitgtk_4_1,
  desktop-file-utils,
  darwin,
}:

let
  linuxLibraries = [
    at-spi2-atk
    cairo
    gdk-pixbuf
    glib
    glib-networking
    gsettings-desktop-schemas
    gtk3
    hicolor-icon-theme
    libayatana-appindicator
    librsvg
    libsoup_3
    openssl
    pango
    webkitgtk_4_1
  ];

  darwinFrameworks = lib.optionals stdenv.isDarwin (
    with darwin.apple_sdk.frameworks; [
      AppKit
      CoreServices
      Security
      WebKit
    ]
  );
in
rustPlatform.buildRustPackage rec {
  pname = "cc-session";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "tyql688";
    repo = "cc-session";
    rev = "v${version}";
    hash = "sha256-u4B5KHqXkR1qWdYwQzQscSysqmwAvbax+yw40Tf25kQ=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-RzILU05OH9ZS0YUE4qOxQqzkgqGAMKh+WUZubcP9Z68=";

  npmDeps = fetchNpmDeps {
    name = "${pname}-${version}-npm-deps";
    inherit src;
    hash = "sha256-o8BvV8DI4i5WCYd7yKEqDYFur4nsPFOOv7iDpOiDTMM=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    npmHooks.npmConfigHook
    nodejs_22
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.isLinux linuxLibraries
  ++ darwinFrameworks;

  doCheck = false;

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'
  '';

  postInstall = ''
    if [ -f "$out/share/applications/CC Session.desktop" ]; then
      mv "$out/share/applications/CC Session.desktop" \
        "$out/share/applications/cc-session.desktop"
      desktop-file-edit \
        --set-key="StartupWMClass" --set-value="cc-session" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/cc-session.desktop
    fi
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage=npmDeps"
      "--url=https://github.com/tyql688/cc-session"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Desktop app for browsing local AI coding sessions";
    homepage = "https://github.com/tyql688/cc-session";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "cc-session";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
