{
  lib,
  fetchFromGitHub,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs_24,
  pkg-config,
  wrapGAppsHook4,
  glib-networking,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  jq,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "gitdesktop";
  version = "0.13.7";

  src = fetchFromGitHub {
    owner = "theBGuy";
    repo = "GitDesktop";
    rev = "v${version}";
    hash = "sha256-rKomUkdDIcynzFEuLPV0oZqhSVQNwNCwYxU6sdbKcIQ=";
  };

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_11; }) {
    inherit pname version src;
    hash = "sha256-6dspDWYj+DZ+9oU2+s4YTeQ1XP7JpLvSLEYpM0l+Ius=";
    fetcherVersion = 4;
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  nativeBuildInputs = [
    cargo-tauri.hook
    pnpmConfigHook
    nodejs_24
    pnpm_11
    pkg-config
    wrapGAppsHook4
    jq
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
    # The upstream tauri.conf resolves the version from "../package.json",
    # which cargo-tauri cannot parse; pin it to the package version.
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"version": "../package.json"' '"version": "${version}"'

    # Disable the built-in updater for the Nix build.
    jq '
      .bundle.createUpdaterArtifacts = false |
      if .plugins.updater then .plugins.updater = {"active": false, "pubkey": "", "endpoints": []} else . end
    ' src-tauri/tauri.conf.json > src-tauri/tauri.conf.json.tmp
    mv src-tauri/tauri.conf.json.tmp src-tauri/tauri.conf.json

    # Patch libayatana-appindicator path if this build pulls it in.
    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  postInstall = ''
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "A fast, native desktop Git client" \
        --set-key="Keywords" --set-value="git;github;gitlab;client;vcs;" \
        --set-key="Categories" --set-value="Development;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit pnpmDeps;

    updateScript = nix-update-script {
      extraArgs = [
        "--generate-lockfile"
        "--lockfile-metadata-path=src-tauri"
        "--subpackage=pnpmDeps"
        "--url=https://github.com/theBGuy/GitDesktop"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "A fast, native desktop Git client";
    homepage = "https://github.com/theBGuy/GitDesktop";
    changelog = "https://github.com/theBGuy/GitDesktop/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "gitdesktop";
    platforms = lib.platforms.linux;
  };
}
