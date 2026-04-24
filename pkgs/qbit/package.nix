{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_9,
  nodejs,
  pnpmConfigHook,
  pkg-config,
  perl,
  cargo-tauri,
  wrapGAppsHook4,
  openssl,
  glib,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  librsvg,
  libayatana-appindicator,
  glib-networking,
  desktop-file-utils,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "qbit";
  version = "0.2.43";

  src = fetchFromGitHub {
    owner = "qbit-ai";
    repo = "qbit";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+ipr/iNN3xUyjxI5SnHWBNXVovSlHmqwLHjC51dDpUM=";
  };

  cargoRoot = "backend";
  buildAndTestSubdir = "backend/crates/qbit";

  cargoHash = "sha256-kcyuyoZtGehv1de6SY9q1fB6qE2IzsGebi6qcLuz98k=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_9;
    fetcherVersion = 3;
    hash = "sha256-Y8NkclXbHHnofwKxfdRMu/TOeUnYxdBU3DDry5Ik5i8=";
  };

  nativeBuildInputs = [
    pkg-config
    pnpm_9
    pnpmConfigHook
    nodejs
    perl
    cargo-tauri.hook
    wrapGAppsHook4
    desktop-file-utils
  ];

  buildInputs = [
    openssl
    glib
    gtk3
    libsoup_3
    webkitgtk_4_1
    librsvg
    libayatana-appindicator
    glib-networking
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  tauriBuildFlags = [
    # Skip tauri version mismatch check (upstream has mismatched plugin versions)
    "--ignore-version-mismatches"
  ];

  postPatch = ''
    # Fix libayatana-appindicator path
    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  doCheck = false;

  postInstall = ''
    desktop-file-edit \
      --set-comment "Open-source agentic IDE" \
      --set-key="Keywords" --set-value="ai;ide;terminal;coding;development;" \
      --set-key="StartupWMClass" --set-value="qbit" \
      --set-key="Categories" --set-value="Development;IDE;Utility;" \
      $out/share/applications/qbit.desktop
  '';

  meta = {
    description = "Open-source agentic IDE powered by AI";
    homepage = "https://github.com/qbit-ai/qbit";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "qbit";
    platforms = lib.platforms.linux;
  };
})
