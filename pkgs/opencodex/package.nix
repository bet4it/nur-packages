{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bun,
  nix-update-script,
}:

let
  pname = "opencodex";
  version = "2.34.0";

  # The npm tarball published to the registry is the source of truth. Its URL
  # embeds `${version}`, so nix-update's npm version fetcher (keyed on the
  # registry.npmjs.org host) detects new releases and rewrites both the version
  # and this URL in one pass.
  src = fetchurl {
    url = "https://registry.npmjs.org/@bitkyc08/opencodex/-/opencodex-${version}.tgz";
    hash = "sha256-f9B6RKb1KSiYAa//0J48bn8AJ60PFD2b68m0fHHyrbs=";
  };

  # The npm tarball omits its lockfile, so fetch the release-matching one from
  # the upstream tag. This pins the resolved dependency tree. The URL embeds
  # `${version}`, so it tracks the version update automatically; only its hash
  # needs refreshing via `--subpackage=bunLock`.
  #
  # This is wrapped in a (trivial) fixed-output derivation rather than a bare
  # `fetchurl` so that the derivation exposes a `src` attribute: nix-update
  # locates a package's file via `builtins.unsafeGetAttrPos "src"`, which for a
  # bare `fetchurl` falls back to `meta.position` and resolves to nixpkgs'
  # read-only `fetchurl/default.nix`. The wrapper keeps the position here.
  bunLock = stdenvNoCC.mkDerivation {
    name = "${pname}-${version}-bun-lock";
    src = fetchurl {
      url = "https://raw.githubusercontent.com/lidge-jun/opencodex/v${version}/bun.lock";
      hash = "sha256-KabPatTEdbXsD7zBBLAy+9spP+0S6xfYA85iZIHn4vU=";
    };

    dontBuild = true;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      cp "$src" "$out"
      runHook postInstall
    '';

    outputHashMode = "flat";
    outputHash = "sha256-KabPatTEdbXsD7zBBLAy+9spP+0S6xfYA85iZIHn4vU=";
  };

  # Fixed-output derivation that captures the bun-installed node_modules tree.
  # Hermetic and cached by hash, so the main derivation never touches the
  # network. Its hash is refreshed via `--subpackage=bunDeps` after a version
  # bump, since it rebuilds from the new `src` and `bunLock`.
  bunDeps = stdenvNoCC.mkDerivation {
    name = "${pname}-${version}-bun-deps";
    inherit src;
    sourceRoot = "package";

    nativeBuildInputs = [ bun ];

    postPatch = ''
      cp "${bunLock}" bun.lock
    '';

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR/home"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      mkdir -p "$HOME" "$XDG_CACHE_HOME"

      # Nix supplies Bun at runtime; --ignore-scripts skips the npm `bun`
      # package's postinstall, which downloads another platform binary.
      bun install --frozen-lockfile --production --backend=copyfile --ignore-scripts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # The Nix wrapper supplies Bun, so do not retain upstream's unused npm
      # copy of the Bun runtime or Bun's install cache.
      rm -rf node_modules/.cache node_modules/bun node_modules/@oven
      rm -f node_modules/.bin/bun node_modules/.bin/bunx

      mkdir -p "$out"
      cp -r node_modules "$out/node_modules"

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHash = "sha256-Om6WjJZlqCEavVrghjn9CGrQx3PS07JwTYThuQH8fl0=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version src;

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    package_out="$out/lib/opencodex"
    mkdir -p "$package_out"
    cp -r bin gui src package.json "$package_out/"
    cp -r "${bunDeps}/node_modules" "$package_out/node_modules"

    # makeWrapper joins <interpreter> <args...>, so the script path is
    # itself an argument and must come after any prefix flags.
    makeWrapper ${lib.getExe bun} "$out/bin/ocx" \
      --add-flags "$package_out/src/cli/index.ts"

    ln -s ocx "$out/bin/opencodex"

    runHook postInstall
  '';

  passthru = {
    inherit bunDeps bunLock;

    # nix-update detects the version from the npm registry URL in `src`. After
    # the version is rewritten, the two fixed-output subpackages must have their
    # hashes recomputed, since both reference `${version}` in their URLs/build.
    # `bunLock` is listed first because `bunDeps` builds from it.
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage=bunLock"
        "--subpackage=bunDeps"
      ];
    };
  };

  meta = {
    description = "Universal provider proxy for OpenAI Codex, Claude Code, Claude Desktop & Grok Build";
    homepage = "https://github.com/lidge-jun/opencodex";
    changelog = "https://github.com/lidge-jun/opencodex/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "ocx";
    platforms = lib.platforms.unix;
    maintainers = [ ];
  };
})
