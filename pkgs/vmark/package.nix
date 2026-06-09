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
  makeBinaryWrapper,
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
  pname = "vmark";
  version = "0.8.4";

  src = fetchFromGitHub {
    owner = "xiaolai";
    repo = "vmark";
    rev = "v${version}";
    hash = "sha256-WRvRz3/bRw2NojZHhS1MNXtFWdGjgL+WZy1tZ1sjq04=";
  };

  targetTriple =
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    }
    .${stdenv.hostPlatform.system} or (throw "unsupported system: ${stdenv.hostPlatform.system}");

  pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_10; }) {
    inherit pname version src;
    hash = "sha256-DyLu38MxYamP970SG5LXqYl1jxmWteF7FZi3/MMvjG4=";
    fetcherVersion = 3;
  };

  vmark-mcp-server = stdenv.mkDerivation {
    pname = "vmark-mcp-server";
    inherit version src pnpmDeps;

    nativeBuildInputs = [
      nodejs_22
      pnpm_10
      pnpmConfigHook
      makeBinaryWrapper
    ];

    buildPhase = ''
      runHook preBuild

      pnpm --filter @vmark/mcp-server build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm644 vmark-mcp-server/package.json \
        "$out/lib/vmark-mcp-server/package.json"
      cp -R vmark-mcp-server/dist "$out/lib/vmark-mcp-server/dist"

      makeWrapper ${lib.getExe nodejs_22} "$out/bin/vmark-mcp-server" \
        --add-flags "$out/lib/vmark-mcp-server/dist/cli.js"

      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src pnpmDeps;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-dqOOvD3F+6izKyxzlhyFh/R6pY7FWN7z84VFKeX6yX8=";
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

    install -Dm755 ${vmark-mcp-server}/bin/vmark-mcp-server \
      "src-tauri/binaries/vmark-mcp-server-${targetTriple}"
  '';

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    libappindicatorSys=$(find "$cargoDepsCopy" -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
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
    if [ -f "$out/share/applications/VMark.desktop" ]; then
      mv "$out/share/applications/VMark.desktop" \
        "$out/share/applications/vmark.desktop"
      desktop-file-edit \
        --set-key="StartupWMClass" --set-value="vmark" \
        --set-key="Categories" --set-value="Development;TextEditor;" \
        "$out/share/applications/vmark.desktop"
    fi
  '';

  passthru = {
    inherit vmark-mcp-server;

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=pnpmDeps"
        "--url=https://github.com/xiaolai/vmark"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Plain-text workspace where humans and AI collaborate";
    homepage = "https://github.com/xiaolai/vmark";
    changelog = "https://github.com/xiaolai/vmark/releases/tag/v${version}";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "vmark";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
