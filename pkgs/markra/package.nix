{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs_22,
  pkg-config,
  wrapGAppsHook4,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
  glib-networking,
  libayatana-appindicator,
  libsoup_3,
  openssl,
  webkitgtk_4_1,
  zenity,
}:

rustPlatform.buildRustPackage rec {
  pname = "markra";
  version = "2.10.3";

  src = fetchFromGitHub {
    owner = "markrahq";
    repo = "markra";
    rev = "v${version}";
    hash = "sha256-DNLRayVDQet1aC8o6+j/tyg5oJD/iC4azWKscqX6AkQ=";
  };

  cargoRoot = "apps/desktop/src-tauri";
  buildAndTestSubdir = "apps/desktop/src-tauri";
  cargoHash = "sha256-bSlvno2JyVYLqpReavV5q/lSYs1Tjmn8pJ4I6evIz5I=";

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_10; }) {
    inherit pname version src;
    hash = "sha256-4fu5YoQW1iGfbdoj5VMQ7fSFZi6Q/d6MwvoKCTyd0Ns=";
    fetcherVersion = 3;
  };

  pnpmRoot = ".";

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs_22
    pnpm_10
    pnpmConfigHook
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  preConfigure = ''
    export HOME=$TMPDIR
  '';

  postPatch = ''
    libappindicatorSys=$(find "$cargoDepsCopy" -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.getBin zenity}/bin)
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    if [ -f "$out/share/applications/"*.desktop ]; then
      desktop-file-edit \
        --set-comment "AI-native Markdown editor" \
        --set-key="Keywords" --set-value="markdown;editor;ai;tauri;" \
        --set-key="Categories" --set-value="Office;TextEditor;" \
        "$out/share/applications/"*.desktop
    fi
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage=pnpmDeps"
      "--url=https://github.com/markrahq/markra"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "AI-native Markdown editor";
    homepage = "https://github.com/markrahq/markra";
    changelog = "https://github.com/markrahq/markra/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "markra";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
