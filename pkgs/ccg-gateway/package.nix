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
  pname = "ccg-gateway";
  version = "1.6.1";

  src = fetchFromGitHub {
    owner = "mos1128";
    repo = "ccg-gateway";
    rev = "v${version}";
    hash = "sha256-fOsAWiIjHcDKPETYiS+GoX+Hci+MxkEd1k2DrBRfByo=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-o2sS3a+NpJkfQdHLT15LhptCQ1h21squvH7b4BAPuBo=";

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    sourceRoot = "${src.name}/frontend";
    hash = "sha256-jOHPOrJTIZRXi8ADkUb+fC6I9r9Ife61mtLa0HjFH64=";
    fetcherVersion = 3;
  };

  pnpmRoot = "frontend";

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

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  preConfigure = ''
    export HOME=$TMPDIR
  '';

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"beforeDevCommand": "pnpm install && pnpm dev",' '"beforeDevCommand": "pnpm --dir frontend dev",' \
      --replace-fail '"beforeBuildCommand": "pnpm install && pnpm build",' '"beforeBuildCommand": "pnpm --dir frontend build",'

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
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "Desktop gateway manager for Claude Code, Codex and Gemini CLI" \
        --set-key="Keywords" --set-value="ai;gateway;claude;codex;gemini;proxy;" \
        --set-key="Categories" --set-value="Development;Network;" \
        $out/share/applications/*.desktop
    fi
  '';

  meta = {
    description = "Desktop AI model gateway and manager for Claude Code, Codex and Gemini CLI";
    homepage = "https://github.com/mos1128/ccg-gateway";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ccg-gateway";
    platforms = lib.platforms.linux;
  };
}
