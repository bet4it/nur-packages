{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nix-update-script,
  electron,
  nodejs_22,
  python3,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  libuv,
}:

let
  version = "0.1.99";

  rawSrc = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "v${version}";
    hash = "sha256-vTlKJn/PEH3FYqVqU1YLqKL/+uMHfNkB9LIGOu2C7sM=";
  };

  npmDeps = fetchNpmDeps {
    name = "paseo-desktop-${version}-npm-deps";
    src = rawSrc;
    hash = "sha256-c3FItM+qFwZ/B21jOJ0W33LFZn1LUk4qNRbBekVT5vU=";
  };
in
buildNpmPackage rec {
  pname = "paseo-desktop";
  inherit version npmDeps;

  src = rawSrc;

  nodejs = nodejs_22;

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    python3
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libuv
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    EXPO_NO_TELEMETRY = "1";
    CI = "1";
  };

  dontNpmBuild = true;

  postPatch = ''
    substituteInPlace packages/desktop/src/main.ts \
      --replace-fail 'if (!app.isPackaged) {' 'if (!app.isPackaged && process.env.PASEO_DESKTOP_USE_DEV_SERVER === "1") {'
  '';

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    npm rebuild node-pty
    npm run build:server
    npm run build:app-deps
    (
      cd packages/app
      PASEO_WEB_PLATFORM=electron npx expo export --platform web
    )
    npm run build:main --workspace=@getpaseo/desktop
    npm prune --omit=dev --no-save

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appRoot="$out/lib/paseo-desktop"
    export appRoot
    mkdir -p "$appRoot/node_modules/@getpaseo" "$out/bin" "$out/share/pixmaps"

    node <<EOF
    const fs = require("fs");
    const path = require("path");

    const srcRoot = process.cwd();
    const outRoot = process.env.appRoot;

    const workspaceEntries = new Map([
      ["desktop", ["package.json", "dist", "assets"]],
      ["cli", ["package.json", "dist", "bin"]],
      ["server", ["package.json", "dist"]],
      ["client", ["package.json", "dist"]],
      ["protocol", ["package.json", "dist"]],
      ["relay", ["package.json", "dist"]],
      ["highlight", ["package.json", "dist"]],
      ["app", ["package.json", "dist", "assets"]],
    ]);

    const runtimeWorkspaces = [
      "desktop",
      "cli",
      "server",
      "client",
      "protocol",
      "relay",
      "highlight",
    ];

    function workspaceDest(name) {
      return path.join(outRoot, "node_modules", "@getpaseo", name);
    }

    function copyMinimalWorkspace(name) {
      const dest = workspaceDest(name);
      fs.mkdirSync(dest, { recursive: true });

      for (const entry of workspaceEntries.get(name) ?? []) {
        const src = path.join(srcRoot, "packages", name, entry);
        if (fs.existsSync(src)) {
          fs.cpSync(src, path.join(dest, entry), {
            recursive: true,
            dereference: true,
          });
        }
      }
    }

    function resolvePackageDir(fromDir, name) {
      let current = fromDir;
      const parts = ["node_modules", ...name.split("/")];

      while (true) {
        const candidate = path.join(current, ...parts);
        if (fs.existsSync(path.join(candidate, "package.json"))) {
          return candidate;
        }

        const parent = path.dirname(current);
        if (parent === current) {
          return null;
        }
        current = parent;
      }
    }

    function mapDest(pkgDir) {
      const rel = path.relative(srcRoot, pkgDir);
      if (rel.startsWith("packages/")) {
        const parts = rel.split(path.sep);
        return path.join(workspaceDest(parts[1]), ...parts.slice(2));
      }
      return path.join(outRoot, rel);
    }

    for (const name of workspaceEntries.keys()) {
      copyMinimalWorkspace(name);
    }

    const queue = [];
    const seen = new Set();

    for (const name of runtimeWorkspaces) {
      const pkgDir = path.join(srcRoot, "packages", name);
      const pkg = JSON.parse(fs.readFileSync(path.join(pkgDir, "package.json"), "utf8"));

      for (const dep of Object.keys(pkg.dependencies ?? {})) {
        queue.push({ fromDir: pkgDir, name: dep });
      }
      for (const dep of Object.keys(pkg.optionalDependencies ?? {})) {
        queue.push({ fromDir: pkgDir, name: dep });
      }
    }

    while (queue.length > 0) {
      const { fromDir, name } = queue.pop();
      if (name.startsWith("@getpaseo/")) {
        continue;
      }

      const pkgDir = resolvePackageDir(fromDir, name);
      if (!pkgDir) {
        continue;
      }

      const key = path.relative(srcRoot, pkgDir);
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);

      const dest = mapDest(pkgDir);
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.cpSync(pkgDir, dest, {
          recursive: true,
          dereference: true,
        });
      }

      const pkg = JSON.parse(fs.readFileSync(path.join(pkgDir, "package.json"), "utf8"));
      for (const dep of Object.keys(pkg.dependencies ?? {})) {
        queue.push({ fromDir: pkgDir, name: dep });
      }
      for (const dep of Object.keys(pkg.optionalDependencies ?? {})) {
        queue.push({ fromDir: pkgDir, name: dep });
      }
    }
    EOF

    find "$appRoot/node_modules" -type d -name .bin -prune -exec rm -rf {} +
    find "$appRoot/node_modules" -xtype l -delete

    if [ -d skills ]; then
      cp -a skills "$appRoot/"
    fi

    install -m 444 packages/desktop/assets/icon.png "$out/share/pixmaps/paseo.png"
    install -Dm444 packages/desktop/assets/32x32.png "$out/share/icons/hicolor/32x32/apps/paseo.png"
    install -Dm444 packages/desktop/assets/64x64.png "$out/share/icons/hicolor/64x64/apps/paseo.png"
    install -Dm444 packages/desktop/assets/128x128.png "$out/share/icons/hicolor/128x128/apps/paseo.png"
    install -Dm444 packages/desktop/assets/128x128@2x.png "$out/share/icons/hicolor/256x256/apps/paseo.png"
    install -Dm444 packages/desktop/assets/icon.png "$out/share/icons/hicolor/512x512/apps/paseo.png"

    makeWrapper ${lib.getExe electron} "$out/bin/paseo-desktop" \
      --add-flags "--no-sandbox" \
      --add-flags "$appRoot/node_modules/@getpaseo/desktop" \
      --inherit-argv0 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "paseo";
      desktopName = "Paseo";
      exec = "paseo-desktop %U";
      icon = "paseo";
      comment = "Desktop GUI for Paseo";
      categories = [ "Development" ];
      startupWMClass = "Paseo";
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/getpaseo/paseo"
      "--use-github-releases"
      "--version-regex=^v([0-9]+\\.[0-9]+\\.[0-9]+)$"
    ];
  };

  meta = {
    description = "Desktop GUI for Paseo, a self-hosted app for AI coding agents";
    homepage = "https://github.com/getpaseo/paseo";
    license = lib.licenses.agpl3Plus;
    mainProgram = "paseo-desktop";
    platforms = lib.platforms.linux;
  };
}
