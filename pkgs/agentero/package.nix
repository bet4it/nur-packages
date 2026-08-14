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
  version = "0.6.0";

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
  pname = "agentero";
  inherit version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "poco-ai";
    repo = "Agentero";
    rev = "v${finalAttrs.version}";
    hash = "sha256-sirS4Lnfyp7EzGoXFrQeSTkNkOvQ3cBaaMksYjq1JjU=";
  };

  # Vendor the whole workspace so the `cli` member (built in preBuild) is
  # covered too. The repo ships a stale src-tauri/Cargo.lock that pins
  # agent-client-protocol 1.2.0 while the workspace lock pins 1.3.0, so
  # remove it to let cargo fall back to the workspace-root Cargo.lock.
  cargoRoot = "./.";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-MuJhuwu0wnTIJbVGPMQuBs9NNQndvwkdO+tn2WIhi1Q=";

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_11; }) {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-lVYh4OOF7O9o+7QtIGJ8KQCx1jlAs/2V4NH0HX5yFTw=";
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
      # -p agentero-cli` out-of-band, which fights the Nix cargo vendor) and
      # disable updater artifacts. We rebuild the bundled CLI + frontend
      # manually in preBuild.
      jq '
        del(.build.beforeBuildCommand) |
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

  # Mirror what `pnpm cli:bundle:release && pnpm build` (the stripped
  # beforeBuildCommand) does, but through Nix's cargo vendor so all cargo
  # invocations are offline.
  preBuild = ''
    # 1) Seed the externalBin stub so tauri-build's generate_context! accepts
    #    `binaries/agentero-cli-<triple>` while agentero_lib compiles.
    triple="$(rustc --print host-tuple)"
    mkdir -p src-tauri/binaries
    stub="src-tauri/binaries/agentero-cli-''${triple}"
    printf '#!/bin/sh\necho "agentero-cli stub" >&2\nexit 1\n' > "$stub"
    chmod +x "$stub"

    # 2) Build the headless CLI (same package prepare-bundled-cli.mjs builds).
    cargo build --offline --release -p agentero-cli

    # 3) Replace the stub with the real binary Tauri will embed via externalBin.
    cp target/release/agentero-cli "$stub"
    chmod +x "$stub"

    # 4) Frontend (`pnpm build` from the stripped beforeBuildCommand).
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
    if [ -f "$out/share/applications/"*.desktop ]; then
      desktop-file-edit \
        --set-comment "AI coding agent desktop app" \
        --set-key="Keywords" --set-value="ai;agent;tauri;coding;vault;" \
        --set-key="StartupWMClass" --set-value="Agentero" \
        --set-key="Categories" --set-value="Development;Utility;" \
        "$out/share/applications/"*.desktop
    fi
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
    mainProgram = "agentero";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
