{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pkg-config,
  openssl,
  glib,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  librsvg,
  pnpm_10,
  nodejs_22,
  pnpmConfigHook,
  wrapGAppsHook4,
  cargo-tauri,
  perl,
  systemdLibs,
  libayatana-appindicator,
  desktop-file-utils,
  glib-networking,
}:

let
  pname = "nyaterm";
  version = "1.2.8";

  src = fetchFromGitHub {
    owner = "nyakang";
    repo = "nyaterm";
    rev = "v${version}";
    hash = "sha256-WUqlOhd0dG+aCgxX0awO7FOFrcZy5jfeBrbk0IFnx/I=";
  };

  targetTriple =
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
    }
    .${stdenv.hostPlatform.system} or (throw "unsupported system: ${stdenv.hostPlatform.system}");

  # Sidecar is a separate crate with its own Cargo.lock and is not a
  # member of the src-tauri workspace, so it must be vendored on its own.
  nyaterm-mcp = rustPlatform.buildRustPackage {
    pname = "nyaterm-mcp";
    inherit version src;

    cargoRoot = "src-tauri/crates/nyaterm-mcp";
    buildAndTestSubdir = "src-tauri/crates/nyaterm-mcp";
    cargoHash = "sha256-C6OTINR4gkmPI/wyzS9sPa+N4dlDFE7ZmRvUeZ5oxyg=";

    doCheck = false;
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  nativeBuildInputs = [
    pkg-config
    pnpm_10
    pnpmConfigHook
    nodejs_22
    wrapGAppsHook4
    cargo-tauri.hook
    perl
    desktop-file-utils
  ];

  buildInputs = [
    openssl
    glib
    gtk3
    libsoup_3
    webkitgtk_4_1
    librsvg
    systemdLibs
    libayatana-appindicator
    glib-networking
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-2Qtar7sVKGGhWR2vQsKH4UyUN7WiOoaqKCZcw6IDD1A=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-GP8XvqonTmo9AKGsk55yQ7HayYdMEomU300R29JdpEg=";

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    # pnpm build would otherwise cargo-build the MCP sidecar against
    # crates.io. Use the Nix-built binary instead.
    substituteInPlace package.json \
      --replace-fail 'pnpm build:mcp-sidecar && tsc && vite build' 'tsc && vite build'

    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  preConfigure = ''
    install -Dm755 ${nyaterm-mcp}/bin/nyaterm-mcp \
      "src-tauri/binaries/nyaterm-mcp-${targetTriple}"
  '';

  doCheck = false;

  postInstall = ''
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "A modern remote terminal workspace built with Tauri, React, and Rust" \
        --set-key="Keywords" --set-value="terminal;ssh;sftp;telnet;serial;tauri;rust;workspace;" \
        --set-key="Categories" --set-value="Development;Network;TerminalEmulator;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit nyaterm-mcp;
  };

  meta = {
    description = "A modern remote terminal workspace built with Tauri, React, and Rust";
    homepage = "https://github.com/nyakang/nyaterm";
    changelog = "https://github.com/nyakang/nyaterm/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "nyaterm";
    platforms = lib.platforms.linux;
  };
}
