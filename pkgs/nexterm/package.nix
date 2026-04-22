{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  fixup-yarn-lock,
  nodejs,
  yarn,
  python311,
  pkg-config,
  vips,
  makeWrapper,
  autoPatchelfHook,
  yarnConfigHook,
}:

stdenv.mkDerivation rec {
  pname = "nexterm";
  version = "1.2.0-BETA";

  src = fetchFromGitHub {
    owner = "gnmyt";
    repo = "Nexterm";
    rev = "v${version}";
    hash = "sha256-5or9vRC20KDfBjyqiyytav3Ign6yuEb77DvnylrhyMc=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-aYEC1hKtc3gDKoUcFzI3bQAnQOTIXFl/jn9Cg67EEHM=";
  };

  clientOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/client/yarn.lock";
    hash = "sha256-+QK890ERqR7P3uEm07fHjkqV9Pt+hBlXzOlYSixbyaU=";
  };

  nativeBuildInputs = [
    nodejs
    yarn
    yarnConfigHook
    fixup-yarn-lock
    python311
    pkg-config
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    vips
  ];

  yarnOfflineCache = offlineCache;

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libsendfile.so"
    "libsocket.so"
  ];

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)

    # Client dependencies configuration
    cd client

    mkdir -p offline-cache
    cp -r $clientOfflineCache/* offline-cache/
    chmod -R u+w offline-cache

    fixup-yarn-lock yarn.lock
    yarn config --offline set yarn-offline-mirror $PWD/offline-cache

    echo "Checking loose_envify in client cache:"
    ls -l offline-cache/loose_envify___loose_envify_1.4.0.tgz || echo "Missing loose_envify"

    cd ..

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # Install and build client
    (
      export HOME=$(mktemp -d)
      cd client
      fixup-yarn-lock yarn.lock
      yarn config --offline set yarn-offline-mirror $clientOfflineCache
      yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts
      
      # Remove unsupported platforms to avoid autoPatchelf errors
      rm -rf node_modules/sass-embedded-linux-musl-*
      rm -rf node_modules/sass-embedded-darwin-*
      rm -rf node_modules/sass-embedded-win32-*
      rm -rf node_modules/sass-embedded-android-*

      patchShebangs node_modules
      autoPatchelf node_modules
      export PATH="$PWD/node_modules/.bin:$PATH"
      yarn build
    )
    # Copy client/dist to expected location
    # Server expects it in ../dist relative to server/index.js (so lib/nexterm/dist)
    # We are in source root.
    # The installPhase copies `client/dist` to `$out/lib/nexterm/dist`.
    # So we don't need to move it here, just ensure it is built.

    # Install root/server dependencies
    # yarnConfigHook already installed them in configurePhase.

    # Rebuild native modules using local node headers
    export npm_config_nodedir=${nodejs}
    npm rebuild --verbose

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/nexterm

    # Copy necessary files
    cp -r package.json yarn.lock server $out/lib/nexterm/

    # Copy node_modules
    cp -r node_modules $out/lib/nexterm/

    # Copy client build artifacts to 'dist' (server expects it in ../dist from server/index.js)
    # server/index.js is in $out/lib/nexterm/server/index.js
    # so ../dist means $out/lib/nexterm/dist
    cp -r client/dist $out/lib/nexterm/dist

    # Clean up node_modules to avoid autoPatchelf errors and reduce size
    chmod -R u+w $out

    echo "Cleaning up incompatible binaries..."
    # Use -type d to avoid deleting js source files that might have similar names
    find $out -type d -name "*-musl-*" -print -exec rm -rf {} +
    find $out -type d -name "*-win32-*" -print -exec rm -rf {} +
    find $out -type d -name "*-darwin-*" -print -exec rm -rf {} +
    find $out -type d -name "*-android-*" -print -exec rm -rf {} +
    find $out -type d -name "*-sunos-*" -print -exec rm -rf {} +
    find $out -type d -name "*-freebsd-*" -print -exec rm -rf {} +
    find $out -type d -name "*-openbsd-*" -print -exec rm -rf {} +
    find $out -type d -name "*-netbsd-*" -print -exec rm -rf {} +

    # Remove incompatible architectures for linux (assuming x64 target)
    find $out -type d -name "*-linux-arm*" -print -exec rm -rf {} +
    find $out -type d -name "*-linux-ppc64*" -print -exec rm -rf {} +
    find $out -type d -name "*-linux-mips*" -print -exec rm -rf {} +
    find $out -type d -name "*-linux-riscv*" -print -exec rm -rf {} +
    find $out -type d -name "*-linux-s390x*" -print -exec rm -rf {} +
    find $out -type d -name "*-linux-loong64*" -print -exec rm -rf {} +

    runHook postInstall
  '';

  postFixup = ''
    # Patch server/index.js to support configurable DATA_DIR
    substituteInPlace $out/lib/nexterm/server/index.js \
      --replace-fail 'const CERTS_DIR = path.join(__dirname, "../data/certs");' \
                     'const DATA_DIR = process.env.NEXTERM_DATA_PATH || path.join(__dirname, "../data"); const CERTS_DIR = path.join(DATA_DIR, "certs");'

    # Patch server/utils/database.js to support configurable DATA_DIR
    substituteInPlace $out/lib/nexterm/server/utils/database.js \
      --replace-fail 'const STORAGE_PATH = `data/nexterm.db`;' \
                     "const path = require('path'); const DATA_DIR = process.env.NEXTERM_DATA_PATH || 'data'; const STORAGE_PATH = path.join(DATA_DIR, 'nexterm.db');"

    # Patch server/utils/recordingService.js to support configurable DATA_DIR
    substituteInPlace $out/lib/nexterm/server/utils/recordingService.js \
      --replace-fail 'const RECORDINGS_DIR = path.join(__dirname, "../../data/recordings");' \
                     'const DATA_DIR = process.env.NEXTERM_DATA_PATH || path.join(__dirname, "../../data"); const RECORDINGS_DIR = path.join(DATA_DIR, "recordings");'

    makeWrapper ${nodejs}/bin/node $out/bin/nexterm \
      --add-flags "$out/lib/nexterm/server/index.js" \
      --set NODE_ENV production \
      --run 'export NEXTERM_DATA_PATH=''${NEXTERM_DATA_PATH:-/var/lib/nexterm}' \
      --prefix PATH : ${lib.makeBinPath [ ]}
  '';

  meta = with lib; {
    description = "Open source server management software for SSH, VNC, and RDP";
    homepage = "https://github.com/gnmyt/Nexterm";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nexterm";
  };
}
