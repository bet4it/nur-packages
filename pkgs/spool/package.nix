{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  python3,
  pkg-config,
}:

let
  version = "0.8.5";

  npmTarball = fetchurl {
    url = "https://registry.npmjs.org/@spool-lab/cli/-/cli-${version}.tgz";
    hash = "sha256-kltPaAoGF+7ROl9RbK7U2N0YVKj41kREqJd0J8mIYt8=";
  };

  # The published npm tarball for @spool-lab/cli doesn't ship a
  # package-lock.json, so one is vendored here (generated with
  # `npm install --package-lock-only` against the unpacked tarball) to
  # let fetchNpmDeps resolve a reproducible dependency set.
  src = runCommand "spool-cli-src-${version}" { } ''
    mkdir -p $out
    tar -xzf ${npmTarball} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "spool";
  inherit version src;

  npmDepsHash = "sha256-CrJkBwzmGOd1SR1RvXxR4SWRgUy4lyolUTsKBPg3zXE=";

  nativeBuildInputs = [
    python3
    pkg-config
  ];

  dontNpmBuild = true;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "CLI to publish, read, and resume AI coding agent sessions";
    homepage = "https://github.com/paperboytm/spool";
    changelog = "https://github.com/paperboytm/spool/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "spool";
    maintainers = with lib.maintainers; [ ];
  };
}
