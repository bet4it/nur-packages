{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  python3,
  pkg-config,
}:

buildNpmPackage rec {
  pname = "metapi";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "cita-777";
    repo = "metapi";
    rev = "v${version}";
    hash = "sha256-OfS8iAjP1yU40RNlJeFEvih4jn9Ab4joTgLfRD6e1pQ=";
  };

  npmDepsHash = "sha256-6C4SIoP0+HdIoODkWq6uEJppOOfzFiNf/5FEtTG/Eo0=";

  nodejs = nodejs_22;

  nativeBuildInputs = [
    makeWrapper
    python3
    pkg-config
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    npm_config_nodedir = "${nodejs_22}";
  };

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"node": ">=25.0.0"' '"node": ">=22.0.0"'
  '';

  buildPhase = ''
    runHook preBuild

    npm run build:web
    npm run build:server

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    mkdir -p $out/bin $out/lib/metapi
    cp -r dist drizzle node_modules package.json package-lock.json $out/lib/metapi/

    makeWrapper ${nodejs_22}/bin/node $out/bin/metapi \
      --set NODE_ENV production \
      --run "export DATA_DIR=\"''${DATA_DIR:-''${XDG_DATA_HOME:-\$HOME/.local/share}/metapi}\"; mkdir -p \"\$DATA_DIR\"; ${nodejs_22}/bin/node \"$out/lib/metapi/dist/server/db/migrate.js\"" \
      --add-flags "$out/lib/metapi/dist/server/index.js"

    runHook postInstall
  '';

  meta = {
    description = "Meta-layer management and unified proxy for AI API aggregation platforms";
    homepage = "https://github.com/cita-777/metapi";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "metapi";
    platforms = lib.platforms.linux;
  };
}
