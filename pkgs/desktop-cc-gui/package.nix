{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  rustPlatform,
  cargo-tauri,
  nodejs_20,
  llvmPackages,
  pkg-config,
  cmake,
  openssl,
  alsa-lib,
  gtk3,
  libxkbcommon,
  librsvg,
  libsoup_3,
  webkitgtk_4_1,
  glib-networking,
  libayatana-appindicator,
  wrapGAppsHook4,
  desktop-file-utils,
  writableTmpDirAsHomeHook,
}:

let
  pname = "desktop-cc-gui";
  version = "0.4.6";

  rawSrc = fetchFromGitHub {
    owner = "zhukunpenglinyutong";
    repo = "desktop-cc-gui";
    rev = "v${version}";
    hash = "sha256-nfjKdJk0EBJuB9n8idpCEmxaeYnde77gr1oF3rV+G5Y=";
  };

  preparedSrc = buildNpmPackage {
    pname = "${pname}-prepared-src";
    inherit version;
    src = rawSrc;

    nodejs = nodejs_20;
    npmDepsHash = "sha256-5ksLBFbeoiS7RDYZT+ruBSersA5C+s3Xc+nnzIBqukM=";
    dontNpmBuild = true;
    npmFlags = [
      "--ignore-scripts"
      "--legacy-peer-deps"
    ];

    postPatch = ''
      substituteInPlace package.json \
        --replace-fail '"@codemirror/search": "^6.6.0",' '"@codemirror/search": "^6.6.0", "@codemirror/autocomplete": "^6.20.0", "@codemirror/commands": "^6.10.2", "@codemirror/lint": "^6.9.3",' \
        --replace-fail '"@xterm/xterm": "^5.5.0",' '"@xterm/xterm": "^5.5.0", "antd": "^6.3.1",' \
        --replace-fail '"remark-gfm": "^4.0.1",' '"remark-gfm": "^4.0.1", "remark-breaks": "^4.0.0",'

      cp ${./package-lock.json} package-lock.json
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -R ./. $out/

      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  inherit pname version;
  src = preparedSrc;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "fix-path-env-0.0.0" = "sha256-UygkxJZoiJlsgp8PLf1zaSVsJZx1GGdQyTXqaFv3oGk=";
    };
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    rustPlatform.bindgenHook
    nodejs_20
    pkg-config
    cmake
    wrapGAppsHook4
    desktop-file-utils
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    openssl
    alsa-lib
    gtk3
    libxkbcommon
    librsvg
    libsoup_3
    webkitgtk_4_1
    glib-networking
    libayatana-appindicator
  ];

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  doCheck = false;

  preConfigure = ''
    export HOME=$TMPDIR

    find . -type d -name node_modules -exec chmod -R u+rw {} \;
    find . -path "*/node_modules/.bin" -type d -exec chmod -R u+x {} \;
    patchShebangs .
  '';

  postPatch = ''
    substituteInPlace src/features/composer/components/ChatInputBox/selectors/ConfigSelect.tsx \
      --replace-fail 'onClick={(checked, e) => {' 'onClick={(checked: boolean, e: React.MouseEvent<HTMLButtonElement> | React.KeyboardEvent<HTMLButtonElement>) => {'

    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false' \
      --replace-fail '"pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IENCOUY2RkIzOUFFNTBBQjgKUldTNEN1V2FzMitmeXpxVWkxMXUrM05UVHRJQTNaTHNZcVo4SktSQUJNSVM2VDEzSzVtaUhHWGcK"' '"pubkey": ""'

    if [ -d $cargoDepsCopy/libappindicator-sys-* ]; then
      substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  env = {
    LIBCLANG_PATH = "${lib.getLib llvmPackages.libclang}/lib";
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
  };

  postInstall = ''
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "A desktop GUI for Claude Code" \
        --set-key="Keywords" --set-value="ai;assistant;claude;coding;" \
        --set-key="Categories" --set-value="Development;Utility;" \
        $out/share/applications/*.desktop
    fi
  '';

  meta = {
    description = "Desktop GUI for Claude Code";
    homepage = "https://github.com/zhukunpenglinyutong/desktop-cc-gui";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "cc-gui";
    platforms = lib.platforms.linux;
  };
}
