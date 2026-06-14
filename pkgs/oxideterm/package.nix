{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_9,
  nodejs_22,
  pnpmConfigHook,
  pkg-config,
  cargo-tauri,
  wrapGAppsHook4,
  glib-networking,
  glib,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  librsvg,
  libayatana-appindicator,
  openssl,
  systemdLibs,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

let
  pname = "oxideterm";
  version = "1.6.3";

  src = fetchFromGitHub {
    owner = "AnalyseDeCircuit";
    repo = "oxideterm";
    rev = "v${version}";
    hash = "sha256-Gh03lkxF4uD5eU5kYYHz6pH8rjLij6NcpzQQELdNx4M=";
  };

  cli = rustPlatform.buildRustPackage {
    pname = "${pname}-cli";
    inherit version src;

    cargoRoot = "cli";
    buildAndTestSubdir = "cli";
    cargoHash = "sha256-POnA3JnUHBYdzwGZ2htswhdwKEtroeLKHCZwMKqoHWM=";

    cargoBuildFlags = [
      "--bin"
      "oxt"
    ];

    doCheck = false;

    meta = {
      description = "CLI companion for OxideTerm";
      homepage = "https://github.com/AnalyseDeCircuit/oxideterm";
      license = lib.licenses.gpl3Only;
      mainProgram = "oxt";
      platforms = lib.platforms.linux;
    };
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoHash = "sha256-uED1HraOTrVc2RLcwwABb0Xyr+Mcqq9CaW4d9e5wJkQ=";

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_9;
    fetcherVersion = 3;
    hash = "sha256-JHqybpFvS320MwSURrtcDP1X6Ni9kPwGXVkUCZNv4DY=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    pnpm_9
    pnpmConfigHook
    nodejs_22
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
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
    systemdLibs
  ];

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  doCheck = false;

  preConfigure = ''
    export HOME=$TMPDIR

    mkdir -p src-tauri/cli-bin
    cp ${cli}/bin/oxt src-tauri/cli-bin/oxt
    chmod +x src-tauri/cli-bin/oxt
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

  env = {
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    ln -s ${cli}/bin/oxt $out/bin/oxt

    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "Local-first SSH workspace built with Rust and Tauri" \
        --set-key="Keywords" --set-value="terminal;ssh;sftp;tauri;rust;workspace;" \
        --set-key="Categories" --set-value="Development;Network;TerminalEmulator;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit cli;

    updateScript = ./update.sh;
  };

  meta = {
    description = "Local-first SSH workspace with terminal, SFTP, forwarding, and BYOK AI";
    homepage = "https://github.com/AnalyseDeCircuit/oxideterm";
    changelog = "https://github.com/AnalyseDeCircuit/oxideterm/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "oxideterm";
    platforms = lib.platforms.linux;
  };
}
