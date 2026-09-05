{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  jq,
  moreutils,
  cmake,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  pnpm_11,
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
}:

let
  version = "0.9.4";

  # Prebuilt pdfium pinned to chromium/7897 (what liteparse-pdfium-sys
  # expects). Pointed at via env vars so its build script skips download.
  pdfiumAsset = {
    "x86_64-linux" = "pdfium-linux-x64";
    "aarch64-linux" = "pdfium-linux-arm64";
  }.${stdenv.hostPlatform.system} or (throw "no pdfium asset for ${stdenv.hostPlatform.system}");

  pdfium = stdenv.mkDerivation {
    pname = "pdfium-prebuilt";
    inherit version;
    src = fetchurl {
      url = "https://github.com/run-llama/pdfium-binaries/releases/download/chromium%2F7897/${pdfiumAsset}.tgz";
      hash = {
        "x86_64-linux" = "sha256-r5byH9jp1TlVAT2tHRewA9ASACXnh7fOYRpoXVcodZQ=";
        "aarch64-linux" = lib.fakeHash;
      }.${stdenv.hostPlatform.system} or lib.fakeHash;
    };
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      tar xzf $src -C $out
      runHook postInstall
    '';
  };

  # tesseract-rs (via liteparse's `tesseract` feature) builds leptonica +
  # tesseract from source and downloads the source zips + traineddata unless
  # they already live under `$HOME/.tesseract-rs/`. Pre-fetch everything so
  # the build is fully offline.
  leptonicaSrc = fetchzip {
    url = "https://github.com/DanBloomberg/leptonica/archive/refs/tags/1.84.1.zip";
    hash = "sha256-SAJVm+Qn/HuiENKa5cLRnqezwKPlNWJBGIRScYObkSw=";
  };
  tesseractSrc = fetchzip {
    url = "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.3.4.zip";
    hash = "sha256-IKxzDhSM+BPsKyQP3mADAkpRSGHs4OmdFIA+Txt084M=";
  };
  engTraineddata = fetchurl {
    url = "https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata";
    hash = "sha256-goCu0Hgv4nJXpo6hD+fvMkyg+Nhb0v0UXRwrVgvLZro=";
  };
  turTraineddata = fetchurl {
    url = "https://github.com/tesseract-ocr/tessdata_best/raw/main/tur.traineddata";
    hash = "sha256-4MMzjcF1A9x9M1pQfJrgGytGz9B1YRceHhrFXYXo5Dg=";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agentero-app";
  inherit version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "poco-ai";
    repo = "Agentero";
    rev = "v${finalAttrs.version}";
    hash = "sha256-RLA48UCKQK88kDDZOvVvkF+IBM0lM3bwcSu8RvDzg48=";
  };

  # Vendor the whole workspace so the `cli` member (built in preBuild) is
  # covered too. The repo ships a stale src-tauri/Cargo.lock that pins
  # agent-client-protocol 1.2.0 while the workspace lock pins 1.3.0, so
  # remove it to let cargo fall back to the workspace-root Cargo.lock.
  cargoRoot = "./.";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-IzkkpSZFpooFBIwSVuIFwInmCo7FaaiIRQbfJDLOOsg=";

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_11; }) {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-1gUE7i/lS0vhqOqoyld1QpGE+W+HY53U0LtLmZsDwVs=";
  };
  pnpmRoot = ".";

  doCheck = false;

  nativeBuildInputs = [
    cargo-tauri.hook
    cmake
    jq
    moreutils
    nodejs_22
    pnpm_11
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

  # tesseract-rs needs cmake for its sub-build but stdenv must not run a
  # top-level cmake configure.
  dontUseCmakeConfigure = true;

  env = {
    OPENSSL_NO_VENDOR = true;
    PDFIUM_LIB_PATH = "${pdfium}/lib";
    PDFIUM_INCLUDE_PATH = "${pdfium}/include";
  };

  preConfigure = ''
    export HOME=$TMPDIR
    mkdir -p "$HOME/.tesseract-rs/third_party" "$HOME/.tesseract-rs/tessdata"
    cp -r --no-preserve=mode ${leptonicaSrc} "$HOME/.tesseract-rs/third_party/leptonica"
    cp -r --no-preserve=mode ${tesseractSrc} "$HOME/.tesseract-rs/third_party/tesseract"
    chmod -R u+w "$HOME/.tesseract-rs/third_party"
    cp ${engTraineddata} "$HOME/.tesseract-rs/tessdata/eng.traineddata"
    cp ${turTraineddata} "$HOME/.tesseract-rs/tessdata/tur.traineddata"
  '';

  postPatch =
    ''
      rm -f src-tauri/Cargo.lock

      # Strip the upstream beforeBuildCommand (it runs `cargo build
      # -p agentero-cli` out-of-band, which fights the Nix cargo vendor),
      # remove externalBin (the CLI ships as a separate Nix package), and
      # disable updater artifacts.
      jq '
        del(.build.beforeBuildCommand) |
        .bundle.externalBin = [] |
        .bundle.createUpdaterArtifacts = false |
        .plugins.updater.endpoints = []
      ' src-tauri/tauri.conf.json | sponge src-tauri/tauri.conf.json
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      # libappindicator-sys dlopens libayatana-appindicator3.so.1 at runtime;
      # autoPatchelf/wrapGApps can't catch it.
      substituteInPlace $cargoDepsCopy/*/libappindicator-sys-*/src/lib.rs \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    '';

  # Stage pdfium and build the frontend — the two things the stripped
  # beforeBuildCommand did that tauri-build still needs.
  preBuild = ''
    # 1) Stage pdfium shared library into src-tauri/pdfium/ so tauri-build's
    #    `resources: ["pdfium/*"]` glob matches. This replaces the upstream
    #    `pnpm pdfium:stage` (part of the stripped beforeBuildCommand).
    mkdir -p src-tauri/pdfium
    cp ${pdfium}/lib/libpdfium.so src-tauri/pdfium/libpdfium.so

    # 2) Frontend (`pnpm build` from the stripped beforeBuildCommand).
    pnpm build
  '';

  # wrapGAppsHook4 wraps the binary with GTK/WebKit env; extend it with the
  # WebKit DMABUF flag + libpdfium's libstdc++ lookup path.
  preFixup = ''
    gappsWrapperArgs+=(
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib pdfium ]}
    )
  '';

  postInstall = ''
    # Rename the PATH entry from `agentero` (the cargo bin name) to
    # `agentero-app` so it does not collide with the headless CLI package's
    # `agentero` command in a shared environment (buildEnv). wrapGAppsHook4
    # runs later in fixupPhase and wraps `bin/agentero-app`.
    mv "$out/bin/agentero" "$out/bin/agentero-app"

    # Tauri uses the `identifier` field from tauri.conf.json
    # ("com.poco-ai.agentero") as the GTK application_id / Wayland app_id.
    # GNOME Shell matches running windows to .desktop files by comparing
    # the app_id against the .desktop filename and StartupWMClass. If they
    # don't match, the taskbar/dock shows no icon. Rename the desktop file
    # and icon to use the reverse-DNS identifier so all three align.
    if [ -f "$out/share/applications/Agentero.desktop" ]; then
      mv "$out/share/applications/Agentero.desktop" \
        "$out/share/applications/com.poco-ai.agentero.desktop"
      desktop-file-edit \
        --set-comment "AI coding agent desktop app" \
        --set-key="Exec" --set-value="agentero-app" \
        --set-key="Icon" --set-value="com.poco-ai.agentero" \
        --set-key="Keywords" --set-value="ai;agent;tauri;coding;vault;" \
        --set-key="StartupWMClass" --set-value="com.poco-ai.agentero" \
        --set-key="Categories" --set-value="Development;Utility;" \
        "$out/share/applications/com.poco-ai.agentero.desktop"
    fi

    for icon in "$out"/share/icons/hicolor/*/apps/agentero.png; do
      mv "$icon" "$(dirname "$icon")/com.poco-ai.agentero.png"
    done
  '';

  passthru = {
    inherit pdfium;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=pnpmDeps"
        "--url=https://github.com/poco-ai/Agentero"
        "--use-github-releases"
        "--version-regex=^v([0-9]+\\.[0-9]+\\.[0-9]+)$"
      ];
    };
  };

  meta = {
    description = "AI coding agent desktop app (Tauri)";
    homepage = "https://github.com/poco-ai/Agentero";
    changelog = "https://github.com/poco-ai/Agentero/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "agentero-app";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
