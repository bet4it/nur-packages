{
  lib,
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

rustPlatform.buildRustPackage rec {
  pname = "nyaterm";
  version = "1.1.13";

  src = fetchFromGitHub {
    owner = "nyakang";
    repo = "nyaterm";
    rev = "v${version}";
    hash = "sha256-9bbZFYZH0J0vqLYs/H2HaYGlCS2ItG/YVj6oiR+/qM4=";
  };

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
    hash = "sha256-HdT6ss8B/YfqsGFotUXf3EjlJr7sxIE4dtiPlJHUHjs=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-06qCUXcu+ZB0PjIb0u5XxeNLJGNtWMl+6LzEb05uBR0=";

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'

    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
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
