{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo-tauri,
  bun,
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
  codex,
  gitMinimal,
}:

let
  pname = "codexia";
  version = "0.28.3";

  src = fetchFromGitHub {
    owner = "milisp";
    repo = "codexia";
    rev = "v${version}";
    hash = "sha256-Wcz8UeeIknMjrTTR00GUFHTTgz9gPi2u/fcFrrNDCYw=";
  };

  # Prefetch Node modules using Bun (Fixed Output Derivation)
  node_modules = stdenv.mkDerivation {
    pname = "${pname}-node_modules";
    inherit version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      nodejs
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install --frozen-lockfile --ignore-scripts --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R node_modules $out/
      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-MmgVEmXoDdEmKYSI6Qqd7TjCdPFfNXqmvxlTKTXgvTU=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  buildFeatures = [ "desktop" ];

  patches = [ ./fix-build-0.28.3.patch ];

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "agent-insights-0.1.4" = "sha256-JjeXHgP1X5GiY2/g3dbPRN27PznzH2Y8fecqkOiKqFE=";
      "claude-agent-sdk-rs-0.6.4" = "sha256-ah0Pgb3itTdHB8d0q3rDjh5smsl9hLTyEL0QcUdVpAU=";
      "codex-app-server-protocol-0.114.0" = "sha256-7t+mVwP4+YrG1ciI+OLqsK7TUM9SrDbPsJNrt26iy9c=";
      "codex-finder-0.1.2" = "sha256-uvjrSU+KGxp6mBrCTJICMZpUT3OgAJ2hUaBbELxR18E=";
      "fix-path-env-0.0.0" = "sha256-UygkxJZoiJlsgp8PLf1zaSVsJZx1GGdQyTXqaFv3oGk=";
    };
  };

  preConfigure = ''
    # Copy node_modules
    cp -R ${node_modules}/node_modules .
    chmod -R u+w node_modules
    patchShebangs node_modules

    export HOME=$TMPDIR
    export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

    # Generate TypeScript bindings using codex CLI
    mkdir -p src/bindings
    ${codex}/bin/codex app-server generate-ts -o src/bindings
  '';

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

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
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
    codex
    gitMinimal
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
    libsoup_3
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  preCheck = ''
    export HOME=$TMPDIR
    export GIT_AUTHOR_NAME="Nix Builder"
    export GIT_AUTHOR_EMAIL="nix-builder@example.invalid"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  '';

  postInstall = ''
    if [ -f $out/bin/codexia ]; then
      wrapProgram $out/bin/codexia \
        --prefix PATH : "${lib.makeBinPath [ desktop-file-utils ]}"
    fi

    if [ -f $out/share/applications/codexia.desktop ]; then
      desktop-file-edit \
        --set-comment "AI coding assistant with Codex CLI and Claude Code support" \
        --set-key="Keywords" --set-value="ai;assistant;claude;codex;coding;" \
        --set-key="StartupWMClass" --set-value="codexia" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/codexia.desktop
    fi
  '';

  meta = {
    description = "Agent OS and Toolkit for Codex CLI + Claude Code";
    homepage = "https://github.com/milisp/codexia";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "codexia";
    platforms = lib.platforms.linux;
  };
}
