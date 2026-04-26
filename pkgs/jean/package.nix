{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  rustPlatform,
  cargo-tauri,
  nodejs,
  writableTmpDirAsHomeHook,
  pkg-config,
  wrapGAppsHook4,
  glib-networking,
  gst_all_1,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  desktop-file-utils,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "jean";
  version = "0.1.45";

  src = fetchFromGitHub {
    owner = "coollabsio";
    repo = "jean";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Mjxfh7s4kqNPbYN9fDgrDbtoDeg1UvasWr9rSgsXcyw=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = "sha256-9qboRRZ4su1eLsQvOncL2OUPgCdQD0OHUiYMveLoSkI=";

  node_modules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      nodejs
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;

      runHook postInstall
    '';

    dontFixup = true;
    outputHash = "sha256-FWt3n6sUQtp4sZhhQvjzdgEW24yECuiKXYVrS2teOu8=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  postPatch = ''
    cp -R ${finalAttrs.node_modules}/. .
    find . -type d -name node_modules -exec chmod -R u+rw {} \;
    find . -path "*/node_modules/.bin" -type d -exec chmod -R u+x {} \;
    patchShebangs .

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

  nativeBuildInputs = [
    cargo-tauri.hook
    bun
    nodejs
    writableTmpDirAsHomeHook
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
  ];

  buildInputs = [
    glib-networking
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    libayatana-appindicator
    openssl
    webkitgtk_4_1
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  postInstall = ''
    desktop-file-edit \
      --set-comment "AI Assistant for managing projects and sessions with Claude CLI" \
      --set-key="Keywords" --set-value="ai;assistant;claude;git;worktree;" \
      --set-key="StartupWMClass" --set-value="Jean" \
      --set-key="Categories" --set-value="Development;Utility;" \
      $out/share/applications/Jean.desktop
  '';

  meta = {
    description = "AI assistant for managing multiple projects and sessions with Claude CLI";
    homepage = "https://github.com/coollabsio/jean";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "jean";
    platforms = lib.platforms.linux;
  };
})
