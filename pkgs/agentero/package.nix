{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  cmake,
  nix-update-script,
  rustPlatform,
  pkg-config,
  openssl,
  writableTmpDirAsHomeHook,
}:

let
  version = "0.8.0";

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
    hash = "sha256-Hiy/uafiJ3bpwc2rclavtJtTgeNA0ezZwkXR/3GIkyY=";
  };

  # Vendor the whole workspace; the CLI depends on agentero_lib (src-tauri).
  # The repo ships a stale src-tauri/Cargo.lock that pins agent-client-protocol
  # 1.2.0 while the workspace lock pins 1.3.0, so remove it to let cargo fall
  # back to the workspace-root Cargo.lock.
  cargoRoot = "./.";
  buildAndTestSubdir = "cli";
  cargoHash = "sha256-+Mgae2FGuu2e2uaA3Se/dukVTElna8eFTvDHvdzDDYE=";

  doCheck = false;

  nativeBuildInputs = [
    cmake
    pkg-config
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    openssl
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

  postPatch = ''
    rm -f src-tauri/Cargo.lock
  '';

  # The cargo bin is `agentero-cli`; create a `agentero` symlink so the
  # POSIX command name matches what the agentero-cli SKILL.md expects
  # (same as the desktop app's Settings → Install CLI shim).
  postInstall = ''
    ln -s $out/bin/agentero-cli $out/bin/agentero

    # Install the SKILL.md so home-manager can symlink it into
    # ~/.agents/skills/agentero-cli/ — tracked by the Nix store, so every
    # rebuild picks up the latest version without manual sync.
    install -Dm644 templates/vault/.agents/skills/agentero-cli/SKILL.md \
      $out/share/skills/agentero-cli/SKILL.md
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--url=https://github.com/poco-ai/Agentero"
        "--use-github-releases"
        "--version-regex=^v([0-9]+\\.[0-9]+\\.[0-9]+)$"
      ];
    };
  };

  meta = {
    description = "Headless Agentero CLI for Vault / Catalog (no BYOA)";
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
