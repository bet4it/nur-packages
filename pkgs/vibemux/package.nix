{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
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
  pname = "vibemux";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "yoko19191";
    repo = "vibemux";
    rev = "v${version}";
    hash = "sha256-/NfOFBd1AZOqVF7H3sWR+TkjbOkp0945/liBNF7TeuM=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-frontend";
    inherit version src;

    nodejs = nodejs_22;
    sourceRoot = "${src.name}/apps/desktop";
    npmDepsHash = "sha256-l+jWsgVchlwydEo2plZzHZAQYeAILT3/Ca13pSlNnDM=";

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

  cargoRoot = "apps/desktop/src-tauri";
  buildAndTestSubdir = "apps/desktop/src-tauri";

  cargoHash = "sha256-qnAQVBB4IO0A+eqeanRJRPwAuc2ceat/PiIUkP+7aac=";

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

    cp -R ${frontend}/node_modules apps/desktop/node_modules
    chmod -R u+rw apps/desktop/node_modules
    find apps/desktop/node_modules/.bin -type f -exec chmod u+x {} \;
    patchShebangs apps/desktop/node_modules
  '';

  postPatch = ''
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
        --set-comment "Keyboard-first terminal multiplexer for multitasking and vibe coding workflows" \
        --set-key="Keywords" --set-value="terminal;multiplexer;tauri;svelte;coding;" \
        --set-key="Categories" --set-value="Development;TerminalEmulator;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit frontend;

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=frontend"
        "--url=https://github.com/yoko19191/vibemux"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Keyboard-first terminal multiplexer for ADHD-friendly multitasking and vibe coding workflows";
    homepage = "https://github.com/yoko19191/vibemux";
    changelog = "https://github.com/yoko19191/vibemux/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "vibemux-desktop";
    platforms = lib.platforms.linux;
  };
}
