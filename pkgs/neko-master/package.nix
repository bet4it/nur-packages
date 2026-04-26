{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm,
  nodejs_22,
  python3,
  pkg-config,
  pixman,
  cairo,
  pango,
  sqlite,
  vips,
}:

stdenv.mkDerivation rec {
  pname = "neko-master";
  version = "1.3.6";

  src = fetchFromGitHub {
    owner = "foru17";
    repo = "neko-master";
    rev = "d5c111fe69489cc2749b1eb6209037a055069c19";
    sha256 = "sha256-nnmB9IkjXSML7+uRqVluM37Wsh2ZxtYx7UuDv3+y8H0=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm.configHook
    python3
    pkg-config
  ];

  buildInputs = [
    pixman
    cairo
    pango
    sqlite
    vips
  ];

  pnpmDeps = pnpm.fetchDeps {
    inherit pname version src;
    fetcherVersion = 3;
    hash = "sha256-eGBbAOUqzxDWXwDFvU2wV+hCwSYS44HLqJ8DCQNg54k=";
  };

  # Fix for better-sqlite3 build
  env.npm_config_build_from_source = true;
  env.npm_config_sqlite3_binary_site_mirror = "http://localhost/no-download";
  # Provide node headers for node-gyp
  env.npm_config_nodedir = "${nodejs_22}";

  postPatch = ''
    # Remove Google Fonts dependency which tries to fetch from network
    sed -i '/next\/font\/google/d' "apps/web/app/[locale]/layout.tsx"
    sed -i '/const geistSans = Geist({/,/});/d' "apps/web/app/[locale]/layout.tsx"
    sed -i '/const geistMono = Geist_Mono({/,/});/d' "apps/web/app/[locale]/layout.tsx"
    # Define dummy variables to avoid breaking the JSX template literal
    sed -i '/import .*globals.css/a const geistSans = { variable: "" }; const geistMono = { variable: "" };' "apps/web/app/[locale]/layout.tsx"
  '';

  buildPhase = ''
    runHook preBuild

    # Install dependencies using copy method, ignoring scripts for speed and safety
    pnpm install --offline --frozen-lockfile --package-import-method copy --ignore-scripts

    # Manual build setup for better-sqlite3 (Native Module)

    # 1. Setup node-gyp cache structure
    mkdir -p $HOME/.node-gyp/${nodejs_22.version}
    ln -sfv ${nodejs_22}/include $HOME/.node-gyp/${nodejs_22.version}

    # 2. Locate and build better-sqlite3
    echo "Building better-sqlite3 native module..."
    pushd node_modules/.pnpm/better-sqlite3*/node_modules/better-sqlite3

    # Trigger the release build script manually
    npm run build-release

    # 3. Cleanup build artifacts to reduce closure size
    echo "Cleaning up build artifacts..."
    rm -rf build/Release/{obj.target,sqlite3.a,.deps} deps

    popd

    # Verify the binary exists
    if [ -z "$(find node_modules -name better_sqlite3.node)" ]; then
      echo "ERROR: better_sqlite3.node not found after manual build!"
      exit 1
    fi

    # Build the main project
    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/neko-master
    # Copy entire project to preserve workspace structure and relative symlinks
    cp -r . $out/share/neko-master

    # Setup standalone web assets
    mkdir -p $out/share/neko-master/apps/web/.next/standalone/apps/web/public
    mkdir -p $out/share/neko-master/apps/web/.next/standalone/apps/web/.next/static
    cp -r apps/web/public/* $out/share/neko-master/apps/web/.next/standalone/apps/web/public/
    cp -r apps/web/.next/static/* $out/share/neko-master/apps/web/.next/standalone/apps/web/.next/static/

    mkdir -p $out/bin

    # Collector script
    cat > $out/bin/neko-master-collector <<EOF
    #!/bin/sh
    export NODE_ENV=production
    exec ${nodejs_22}/bin/node $out/share/neko-master/apps/collector/dist/index.js
    EOF
    chmod +x $out/bin/neko-master-collector

    # Web script
    cat > $out/bin/neko-master-web <<EOF
    #!/bin/sh
    export NODE_ENV=production
    exec ${nodejs_22}/bin/node $out/share/neko-master/apps/web/.next/standalone/apps/web/server.js
    EOF
    chmod +x $out/bin/neko-master-web

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Neko Master Dashboard";
    homepage = "https://github.com/foru17/neko-master";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
