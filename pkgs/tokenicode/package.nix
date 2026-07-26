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

let
  # Upstream's tagged pnpm-lock.yaml drifts from package.json (a stale
  # `@tauri-apps/api` specifier: package.json wants ~2.10.0, the lockfile
  # still says ^2), which trips pnpm's --frozen-lockfile check. The
  # resolved version (2.10.1) satisfies both ranges, so just fix up the
  # recorded specifier instead of re-resolving anything. Applied both when
  # computing pnpmDeps and in the main build so the two lockfiles match.
  fixTauriApiSpecifier = ''
    sed -i "/'@tauri-apps\/api':/{n;s/specifier: \^2/specifier: ~2.10.0/}" pnpm-lock.yaml
  '';
in
rustPlatform.buildRustPackage rec {
  pname = "tokenicode";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "yiliqi78";
    repo = "TOKENICODE";
    rev = "v${version}";
    hash = "sha256-IGt7pFASj1VoVBzRWqUNuiJp3e5NSOc/pEbFp5zwXc0=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-kwSsWtMsSl/a6294U1TNU/z4yMp7zxDaX4IHDDzk6B8=";

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_10; }) {
    inherit pname version src;
    hash = "sha256-oBBZUPoKEF+d7tiVVnXr+SMC5A4umTPU5blvidY79X8=";
    fetcherVersion = 3;

    postPatch = fixTauriApiSpecifier;
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
    ${fixTauriApiSpecifier}

    # Disable updater artifacts and pubkey for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    if grep -q '"pubkey":' src-tauri/tauri.conf.json; then
      sed -i 's#"pubkey": "[^"]*"#"pubkey": ""#' src-tauri/tauri.conf.json
    fi

    # Fix libayatana-appindicator path if it exists
    shopt -s nullglob
    libappindicatorSources=("$cargoDepsCopy"/libappindicator-sys-*/src/lib.rs)
    if [ ''${#libappindicatorSources[@]} -gt 0 ]; then
      substituteInPlace "''${libappindicatorSources[@]}" \
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
