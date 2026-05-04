{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
  npm-lockfile-fix,
  rustPlatform,
  cargo-tauri,
  nodejs_22,
  pkg-config,
  cmake,
  openssl,
  glib-networking,
  libayatana-appindicator,
  libsoup_3,
  webkitgtk_4_1,
  wrapGAppsHook4,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

let
  pname = "vibe99";
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "NekoApocalypse";
    repo = "Vibe99";
    rev = "v${version}";

    postFetch = ''
      ${lib.getExe npm-lockfile-fix} $out/package-lock.json
    '';

    hash = "sha256-7MwEqqQO6T1MGcceuOh+KV014vt88t5iZXvBEO/1SDE=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;

    nodejs = nodejs_22;
    npmDepsHash = "sha256-2c6NwRWiFRDHfqTBPWtxD5IXGJyor2yg3DUcJbldC2g=";

    dontNpmBuild = true;
    npmFlags = [
      "--ignore-scripts"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -R node_modules $out/

      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-r9w5T+7YKC0mw9pNEb7GPfi+k7ohQ/SMRElENAhOCAI=";

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs_22
    pkg-config
    cmake
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

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  doCheck = false;

  preConfigure = ''
    export HOME=$TMPDIR

    cp -R ${frontend}/node_modules node_modules
    chmod -R u+rw node_modules
    find node_modules/.bin -type f -exec chmod u+x {} \;
    patchShebangs node_modules
  '';

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"targets": "all"' '"targets": ["deb"]'

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
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "Desktop terminal workspace for agentic coding" \
        --set-key="Keywords" --set-value="terminal;tauri;coding;agent;workspace;" \
        --set-key="Categories" --set-value="Development;TerminalEmulator;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit frontend;

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=frontend"
        "--url=https://github.com/NekoApocalypse/Vibe99"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Desktop terminal workspace for agentic coding";
    homepage = "https://github.com/NekoApocalypse/Vibe99";
    changelog = "https://github.com/NekoApocalypse/Vibe99/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "vibe99";
    platforms = lib.platforms.linux;
  };
}
