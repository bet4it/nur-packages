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
  pname = "cc-sessions-viewer";
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "jerrywu001";
    repo = "cc-sessions-viewer";
    rev = "v${version}";

    postFetch = ''
      ${lib.getExe npm-lockfile-fix} $out/package-lock.json
    '';

    hash = "sha256-VIwa+Z/mxezDihd/77U54g6el/sqYHcdSgUDaDDAVmk=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;

    nodejs = nodejs_22;
    npmDepsHash = "sha256-Hmrr57Q0SN81kFkhvQprqcghBCX6TKJeZroEZR/OlNU=";

    dontNpmBuild = true;
    npmFlags = [
      "--ignore-scripts"
      "--legacy-peer-deps"
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

  # Upstream tags ship a stale Cargo.lock (not regenerated on release),
  # so a vendored one is used instead.
  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs_22
    pkg-config
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
    libsoup_3
  ];

  preConfigure = ''
    export HOME=$TMPDIR

    cp -R ${frontend}/node_modules node_modules
    chmod -R u+rw node_modules
    find node_modules/.bin -type f -exec chmod u+x {} \;
    patchShebangs node_modules
  '';

  postUnpack = ''
    cp ${./Cargo.lock} source/src-tauri/Cargo.lock
  '';

  postPatch = ''
    # Disable updater for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false' \
      --replace-fail '"pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IDRDQjAyNzg1NDkyREM2QjcKUldTM3hpMUpoU2V3VFBJMmVOYnl4S1BwMUIxNWFIbEZWQTBqODZrTnRtOVh4NXl1SDgxd1pORzQK"' '"pubkey": ""'

    # Patch libayatana-appindicator path
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
        --set-comment "Sessions viewer for Claude Code, Codex, Antigravity CLI, and opencode" \
        --set-key="Keywords" --set-value="claude;codex;opencode;ai;session;viewer;" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit frontend;

    updateScript = nix-update-script {
      extraArgs = [
        "--generate-lockfile"
        "--lockfile-metadata-path=src-tauri"
        "--subpackage=frontend"
        "--url=https://github.com/jerrywu001/cc-sessions-viewer"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Sessions viewer for Claude Code, Codex, Antigravity CLI, and opencode";
    homepage = "https://github.com/jerrywu001/cc-sessions-viewer";
    changelog = "https://github.com/jerrywu001/cc-sessions-viewer/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "cc-sessions-viewer";
    platforms = lib.platforms.linux;
  };
}
