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
  pname = "claude-code-history-viewer";
  version = "1.11.0";

  src = fetchFromGitHub {
    owner = "jhlee0409";
    repo = "claude-code-history-viewer";
    rev = "v${version}";
    hash = "sha256-KamZv8MlqB3Wq3IXEpUtFiFsXnRnxRTwbevH2Ip7KfY=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    hash = "sha256-fGXR3WztHAddVL2O4gtfpiaSw8PXgsMWjMRxJtjoONQ=";
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

  postUnpack = ''
    cp ${./Cargo.lock} source/src-tauri/Cargo.lock
  '';

  postPatch = ''
    # Replace just with node/npm
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"beforeBuildCommand": "just frontend-build"' '"beforeBuildCommand": "node scripts/sync-version.cjs && npm run build"'

    # Disable updater artifacts and pubkey for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false' \
      --replace-fail '"pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IDg0RUExOEVGNTlEQzFDRDMKUldUVEhOeFo3eGpxaEZGYkZYcmFKTERPdys5dXh2c1Z5ZU1uTDREZ3RyWDF1bHhSc1JOeW05MzUK"' '"pubkey": ""'

    # Fix libayatana-appindicator path if it exists
    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
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
        --set-comment "Desktop application for exploring and analyzing Claude Code chat history" \
        --set-key="Keywords" --set-value="ai;assistant;claude;" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/*.desktop
    fi
  '';

  meta = {
    description = "Desktop application for exploring and analyzing Claude Code chat history";
    homepage = "https://github.com/jhlee0409/claude-code-history-viewer";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "claude-code-history-viewer";
    platforms = lib.platforms.linux;
  };
}
