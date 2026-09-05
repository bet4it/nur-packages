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
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "gitdesktop";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "theBGuy";
    repo = "GitDesktop";
    rev = "v${version}";
    hash = "sha256-gd5vI0gmY+eHxw9xgvqQAl2nGB3/cXvUGYSmwDIvq6k=";
  };

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_11; }) {
    inherit pname version src;
    hash = "sha256-9Myned3T2nfd8mObDjtr31aDNel1y1yq9jKG+S13dk4=";
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
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false' \
      --replace-fail '"pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IENENkZCNUI4MjM1QzRDM0UKUldRK1RGd2p1TFZ2emJtU3BHcW44TFlhMUMrTVRVRE9iN3RheVJXWnd0R0xYV3JPSXBoajhSUjAK"' '"pubkey": ""'

    # Patch libayatana-appindicator path if this build pulls it in.
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
