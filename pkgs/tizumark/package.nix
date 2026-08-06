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
  desktop-file-utils,
  writableTmpDirAsHomeHook,
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
}:

rustPlatform.buildRustPackage rec {
  pname = "tizumark";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "tizuio";
    repo = "TizuMark";
    rev = "v${version}";
    hash = "sha256-hrJVfIwMjBistsxou6nbpP97bEFKEanP4ukhuzCMbZ0=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      # rust-brotli git dependency (see [patch.crates-io] in Cargo.toml).
      "brotli-8.0.3" = "sha256-5HRCwBCs9xcOdWd15SZ0ryEr4/Fk4IVxYdIGbMyRu98=";
    };
  };

  npmDeps = fetchNpmDeps {
    name = "tizumark-${version}-npm-deps";
    inherit src;
    hash = "sha256-nof78D0ho8tAPfTw4yqusfkj4dzrx8zatRi9fceF2kk=";
  };

  doCheck = false;

  nativeBuildInputs = [
    cargo-tauri.hook
    npmHooks.npmConfigHook
    nodejs_22
    pkg-config
    wrapGAppsHook4
    writableTmpDirAsHomeHook
    desktop-file-utils
  ];

  buildInputs = [
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

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  postPatch = ''
    # npmConfigHook runs `npm ci --ignore-scripts`, so the `prepare`
    # lifecycle script (ensure-vendor + build-renderer) is skipped.
    # build-frontend needs the vendor tree, so fold ensure-vendor into
    # beforeBuildCommand alongside the renderer bundle + frontend build.
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail \
        '"beforeBuildCommand": "npm run build:renderer && npm run build-frontend"' \
        '"beforeBuildCommand": "node scripts/ensure-vendor.mjs && npm run build:renderer && npm run build-frontend"'

    # Tauri's libappindicator-sys dlopens libayatana-appindicator3.so.1
    # at runtime; point it at the nix store copy so the wrapper's
    # LD_LIBRARY_PATH isn't the only thing making it resolvable.
    libappindicatorSys=$(find "$cargoDepsCopy" -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  preConfigure = ''
    export HOME=$TMPDIR
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    if [ -f "$out/share/applications/"*.desktop ]; then
      desktop-file-edit \
        --set-comment "A lightweight cross-platform Markdown editor" \
        --set-key="Keywords" --set-value="markdown;editor;tauri;" \
        --set-key="Categories" --set-value="Office;TextEditor;" \
        "$out/share/applications/"*.desktop
    fi
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage=npmDeps"
      "--url=https://github.com/tizuio/TizuMark"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "A lightweight cross-platform Markdown editor";
    homepage = "https://github.com/tizuio/TizuMark";
    changelog = "https://github.com/tizuio/TizuMark/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "tizumark";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
