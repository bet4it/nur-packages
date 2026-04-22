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
  pname = "cc-switch";
  version = "3.13.0";

  src = fetchFromGitHub {
    owner = "farion1231";
    repo = "cc-switch";
    rev = "v${version}";
    hash = "sha256-JSjAJ/wrs5nxnRZvbwbLEgIGpghTMYgqBzNclgrrwCk=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-FK8iyEW0GQdNXsIcolR4FUMsbVRguFRdk9yg1wwDNu4=";

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    hash = "sha256-bLL8ZcZlUWERcOikFCfN5MPqH/VocCfvDJqrkAPbtPA=";
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
    # Disable updater artifacts for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    # Fix libayatana-appindicator path
    substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    # Rename binary to match pname
    if [ -f "$out/bin/CC Switch" ]; then
      mv "$out/bin/CC Switch" "$out/bin/cc-switch"
    fi

    # Install desktop file
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "All-in-One Assistant for Claude Code, Codex, OpenCode & Gemini CLI" \
        --set-key="Keywords" --set-value="ai;assistant;claude;codex;gemini;coding;" \
        --set-key="StartupWMClass" --set-value="cc-switch" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/*.desktop
    fi
  '';

  meta = {
    description = "A cross-platform desktop All-in-One assistant tool for Claude Code, Codex, OpenCode & Gemini CLI";
    homepage = "https://github.com/farion1231/cc-switch";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "cc-switch";
    platforms = lib.platforms.linux;
  };
}
