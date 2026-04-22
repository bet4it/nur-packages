{
  lib,
  fetchFromGitHub,
  rustPlatform,
  cargo-tauri,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs,
  pkg-config,
  wrapGAppsHook4,
  glib-networking,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "tokenicode";
  version = "0.10.6";

  src = fetchFromGitHub {
    owner = "yiliqi78";
    repo = "TOKENICODE";
    rev = "v${version}";
    hash = "sha256-Bw7rMFYa0nsIClImT5r3m0gPzvemjJydWY2DyzDuMqs=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-1PvJHOPJYarUkv5TuaIygwUpaIuQmyzr4oOXQ8iEpK0=";

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    hash = "sha256-/ALHeLPWAlnRdBbXG6fZKtnztY8obZDORVgzaoUeIyQ=";
    fetcherVersion = 3;
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    pnpmConfigHook
    nodejs
    pnpm_10
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
    libsoup_3
  ];

  preConfigure = ''
    export HOME=$TMPDIR
  '';

  postPatch = ''
    # Disable updater artifacts and pubkey for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    if grep -q '"pubkey":' src-tauri/tauri.conf.json; then
      sed -i 's#"pubkey": "[^"]*"#"pubkey": ""#' src-tauri/tauri.conf.json
    fi

    # Fix libayatana-appindicator path if it exists
    if [ -d $cargoDepsCopy/libappindicator-sys-* ]; then
      substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    # Install desktop file
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "A beautiful GUI for Claude Code" \
        --set-key="Keywords" --set-value="ai;assistant;claude;" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/*.desktop
    fi
  '';

  meta = {
    description = "A beautiful GUI for Claude Code";
    homepage = "https://github.com/yiliqi78/TOKENICODE";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "tokenicode";
    platforms = lib.platforms.linux;
  };
}
