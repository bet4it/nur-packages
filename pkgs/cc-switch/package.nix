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
  version = "3.14.1";

  src = fetchFromGitHub {
    owner = "farion1231";
    repo = "cc-switch";
    rev = "v${version}";
    hash = "sha256-mSTuPTACW4yiR9e43Kp3RcbitbZ3OQUdZsHwZlSn6iQ=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-MgO8VxcE8mHDsLlywJ3zriEXRWjZbJ6L/bfd27r9u5g=";

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    hash = "sha256-Vs+/KLICqciF7dnC3iRH9TFzNCtXDgOkWFPLxdwA0rE=";
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
