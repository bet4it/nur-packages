{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  llvmPackages,
  bun,
  rustPlatform,
  cargo-tauri,
  nodejs,
  writableTmpDirAsHomeHook,
  pkg-config,
  wrapGAppsHook4,
  zig,
  cacert,
  glib-networking,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  desktop-file-utils,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "athas";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "athasdev";
    repo = "athas";
    rev = "v${finalAttrs.version}";
    hash = "sha256-6vDVrE3trlDPth71FCe0nuuvAWhKTNFxektNapeee+Q=";
  };

  buildAndTestSubdir = "src-tauri";

  cargoHash = "sha256-7tu9e4juA7kUMC82bnZxfoMpmKpMMbA1I5x8hypT59E=";

  doCheck = false;

  tauriBuildFlags = [ "--ignore-version-mismatches" ];

  node_modules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      nodejs
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;

      runHook postInstall
    '';

    dontFixup = true;
    outputHash = "sha256-J4MtpOrDoD6FCljtELM2tRCVc/D5R+wcP1FflvuasmM=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  postPatch = ''
    cp -R ${finalAttrs.node_modules}/. .
    find . -type d -name node_modules -exec chmod -R u+rw {} \;
    find . -path "*/node_modules/.bin" -type d -exec chmod -R u+x {} \;
    patchShebangs .

    # Disable updater artifacts and pubkey for Nix build
    substituteInPlace src-tauri/tauri.conf.json \
      --replace-fail '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false' \
      --replace-fail '"pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEJBNDk0QjI4NkVDNDQwRUUKUldUdVFNUnVLRXRKdXV2elJZL3RsOWkvRDJueUwvQjh1UzdMbFBHZmZjV01Ec3lXZ1hFY3V6RkYK"' '"pubkey": ""'

    # Fix libayatana-appindicator path
    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  # Tauri runs beforeBuildCommand (`vp build`) via plain sh, so
  # node_modules/.bin must be on PATH for the vite-plus CLI to resolve.
  preBuild = ''
    export PATH="$PWD/node_modules/.bin:$PATH"
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    bun
    nodejs
    writableTmpDirAsHomeHook
    pkg-config
    wrapGAppsHook4
    zig
    desktop-file-utils
    cacert
  ];

  buildInputs = [
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
  ];

  env = {
    LIBCLANG_PATH = "${lib.getLib llvmPackages.libclang}/lib";
    OPENSSL_NO_VENDOR = true;
    TAURI_SKIP_VERSION_CHECK = "1";
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  postInstall = ''
    # Install desktop file
    if [ -f $out/share/applications/*.desktop ]; then
      desktop-file-edit \
        --set-comment "Athas code editor" \
        --set-key="Keywords" --set-value="editor;code;development;ide;" \
        --set-key="Categories" --set-value="Development;IDE;" \
        $out/share/applications/*.desktop
    fi
  '';

  passthru = {
    inherit (finalAttrs) node_modules;

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=node_modules"
        "--url=https://github.com/athasdev/athas"
        "--use-github-releases"
      ];
    };
  };

  meta = {
    description = "Athas code editor";
    homepage = "https://github.com/athasdev/athas";
    license = lib.licenses.agpl3Plus;
    maintainers = [ ];
    mainProgram = "athas";
    platforms = lib.platforms.linux;
  };
})
