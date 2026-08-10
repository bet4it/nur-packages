{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  makeWrapper,
  nodejs_22,
  patchelf,
  pnpm_10,
  pnpmConfigHook,
  python3,
  pkg-config,
  nix-update-script,
  writableTmpDirAsHomeHook,
}:

let
  pname = "spool";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "bet4it";
    repo = "spool";
    rev = "v${version}";
    hash = "sha256-z5w2+0fEi7CrPWRCPtkpISdm9FpCbDABSs/i5X/7r84=";
  };

  # The CLI transitively depends on @spool-lab/core (which depends on
  # @spool-lab/redact). We list all workspace packages that need to be
  # fetched so fetchPnpmDeps can resolve the full dependency graph.
  pnpmWorkspaces = [
    "@spool-lab/cli"
    "@spool-lab/core"
    "@spool-lab/redact"
  ];
in
stdenv.mkDerivation {
  inherit pname version src pnpmWorkspaces;

  pnpmDeps = fetchPnpmDeps {
    inherit
      pname
      version
      src
      pnpmWorkspaces
      ;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-ATFDq6Oe4nrXs8nKE7f7Tkh+ojw8hdDtwKQlRkcq/2s=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs_22
    patchelf
    pkg-config
    pnpm_10
    pnpmConfigHook
    python3
    writableTmpDirAsHomeHook
  ];

  # libstdc++ needed by the better-sqlite3 native addon at runtime
  buildInputs = [ stdenv.cc.cc.lib ];

  env = {
    npm_config_build_from_source = "true";
    npm_config_fallback_to_build = "true";
  };

  dontNpmInstall = true;

  buildPhase = ''
    runHook preBuild

    export COREPACK_ENABLE_PROJECT_SPEC=0
    export npm_config_manage_package_manager_versions=false
    export npm_config_nodedir=${nodejs_22}

    # Rebuild better-sqlite3 for Node.js (not Electron).
    for betterSqlite in $(find . -path '*/node_modules/better-sqlite3' -type d); do
      (
        cd "$betterSqlite"
        npm run build-release --offline
        rm -rf build/Release/{.deps,obj,obj.target,test_extension.node}
      )
    done

    # Build workspace dependencies in topological order, then the CLI itself.
    pnpm --filter @spool-lab/redact run build
    pnpm --filter @spool-lab/core run build
    pnpm --filter @spool-lab/cli run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Preserve the pnpm symlink layout: packages/cli/node_modules/commander
    # → ../../../node_modules/.pnpm/..., so the root node_modules must be
    # at $out/lib/spool/node_modules and the CLI at $out/lib/spool/packages/cli.
    mkdir -p $out/lib/spool

    # Copy the root node_modules (.pnpm store + workspace symlinks).
    cp -R node_modules $out/lib/spool/node_modules

    # Copy the CLI package with its built dist + bin.
    mkdir -p $out/lib/spool/packages/cli
    cp -R packages/cli/dist $out/lib/spool/packages/cli/dist
    cp -R packages/cli/bin $out/lib/spool/packages/cli/bin
    cp packages/cli/package.json $out/lib/spool/packages/cli/package.json
    cp -R packages/cli/node_modules $out/lib/spool/packages/cli/node_modules

    # Copy built core + redact into their package dirs so workspace
    # symlinks (node_modules/@spool-lab/core → ../../packages/core)
    # resolve at runtime.  Also copy their node_modules so that
    # better-sqlite3, effect, etc. resolve via the pnpm symlink store.
    mkdir -p $out/lib/spool/packages/core
    cp -R packages/core/dist $out/lib/spool/packages/core/dist
    cp packages/core/package.json $out/lib/spool/packages/core/package.json
    cp -R packages/core/node_modules $out/lib/spool/packages/core/node_modules
    mkdir -p $out/lib/spool/packages/redact
    cp -R packages/redact/dist $out/lib/spool/packages/redact/dist
    cp packages/redact/package.json $out/lib/spool/packages/redact/package.json
    cp -R packages/redact/node_modules $out/lib/spool/packages/redact/node_modules

    # The better-sqlite3 native addon lives under node_modules/.pnpm.
    # Patch its RPATH so it can find libstdc++ at runtime.
    for addon in $(find $out/lib/spool -name 'better_sqlite3.node' -type f); do
      patchelf \
        --set-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
        "$addon" || true
    done

    chmod +x $out/lib/spool/packages/cli/bin/spool.js

    makeWrapper ${lib.getExe nodejs_22} "$out/bin/spool" \
      --add-flags "$out/lib/spool/packages/cli/bin/spool.js" \
      --prefix PATH : ${lib.makeBinPath [ nodejs_22 ]}

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage=pnpmDeps"
      "--url=https://github.com/bet4it/spool"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "CLI for searching your local AI coding sessions";
    homepage = "https://github.com/bet4it/spool";
    changelog = "https://github.com/bet4it/spool/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "spool";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.unix;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
}
