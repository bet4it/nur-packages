{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  git,
  llvmPackages,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  fetchNpmDeps,
  npmHooks,
  nodejs_22,
  pkg-config,
  wrapGAppsHook4,
  desktop-file-utils,
  python3,
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

  darwinFrameworks = lib.optionals stdenv.hostPlatform.isDarwin (
    with darwin.apple_sdk.frameworks; [
      AppKit
      CoreServices
      Security
      WebKit
    ]
  );
in
rustPlatform.buildRustPackage rec {
  pname = "agy-switch";
  version = "4.10.10";

  src = fetchFromGitHub {
    owner = "anglee0323";
    repo = "agy-switch";
    rev = "v${version}";
    hash = "sha256-tqUgTHd6Vo1k0K4ZRadytkGkIhG2hZvMZgb0jvddvgc=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-9WOP7V+JKkzwPtwScXA+PEIuEo/g3fO9CQpzbbfCJFE=";

  npmDeps = fetchNpmDeps {
    name = "${pname}-${version}-npm-deps";
    inherit src;
    hash = "sha256-EhALAbKsBDYv3/k9+90UYpIAjoaYd7K3MYtnIdZ3JyA=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    rustPlatform.bindgenHook
    npmHooks.npmConfigHook
    nodejs_22
    pkg-config
    cmake
    git
    wrapGAppsHook4
    desktop-file-utils
    python3
    writableTmpDirAsHomeHook
  ];

  dontUseCmakeConfigure = true;

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux linuxLibraries
  ++ darwinFrameworks;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  doCheck = false;

  postPatch = ''
    if grep -q '"pubkey":' src-tauri/tauri.conf.json; then
      sed -i 's#"pubkey": "[^"]*"#"pubkey": ""#' src-tauri/tauri.conf.json
    fi

    libappindicatorSys=$(find "$cargoDepsCopy" -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  preBuild = ''
    export PATH="$PWD/node_modules/.bin:$PATH"
    npm run build
    cargo build --release --bin agy-switch -j $NIX_BUILD_CORES --target ${stdenv.hostPlatform.rust.rustcTarget} --offline --manifest-path src-tauri/Cargo.toml --target-dir target
    mkdir -p src-tauri/target/release
    cp target/${stdenv.hostPlatform.rust.rustcTarget}/release/agy-switch src-tauri/target/release/agy-switch
    mkdir -p src-tauri/target/${stdenv.hostPlatform.rust.rustcTarget}/release
    cp target/${stdenv.hostPlatform.rust.rustcTarget}/release/agy-switch src-tauri/target/${stdenv.hostPlatform.rust.rustcTarget}/release/agy-switch
  '';

  env = {
    LIBCLANG_PATH = "${lib.getLib llvmPackages.libclang}/lib";
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    install -Dm755 target/${stdenv.hostPlatform.rust.rustcTarget}/release/agy-switch $out/bin/agy-switch

    for desktop in $out/share/applications/*.desktop; do
      if [ -f "$desktop" ]; then
        desktop-file-edit \
          --set-comment "Local Antigravity account switching and usage dashboard" \
          --set-key="Keywords" --set-value="antigravity;agy;account;switcher;dashboard;" \
          --set-key="Categories" --set-value="Development;Utility;" \
          "$desktop"
      fi
    done
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage=npmDeps"
      "--url=https://github.com/anglee0323/agy-switch"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Local Antigravity account switching and usage dashboard";
    homepage = "https://github.com/anglee0323/agy-switch";
    changelog = "https://github.com/anglee0323/agy-switch/releases/tag/v${version}";
    license = lib.licenses.cc-by-nc-sa-40;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "agy-switch-desktop";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
