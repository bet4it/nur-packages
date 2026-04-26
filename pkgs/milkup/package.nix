{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  pnpm,
  nodejs_22,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:

stdenv.mkDerivation rec {
  pname = "milkup";
  version = "1.0.13";

  upstreamSrc = fetchFromGitHub {
    owner = "Auto-Plugin";
    repo = "milkup";
    rev = "9e3e2ae6a0a5912701744c3dc0f8ff8a754d6556";
    hash = "sha256-aOejVQnRrj2+zdd0+IScZGWzJIKU/48Q1fkjbJuDLHA=";
  };

  src = stdenv.mkDerivation {
    pname = "${pname}-src";
    inherit version;
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out"
      cp -R ${upstreamSrc}/. "$out"/
      cp ${./pnpm-lock.yaml} "$out"/pnpm-lock.yaml
    '';
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm.configHook
    makeWrapper
    copyDesktopItems
  ];

  pnpmDeps = pnpm.fetchDeps {
    inherit pname version src;
    fetcherVersion = 3;
    hash = "sha256-37cA97g/giEjwlYQOvlORaPuk1q8n4eUbXiENclokUE=";
  };

  postPatch = ''
    patch -p1 < ${./fix-export.patch}
  '';
  # Electron builder tries to download electron, we want to skip that.
  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/milkup
    cp -r . $out/share/milkup

    # Remove node_modules that are not needed for production if possible,
    # but electron apps often need them. electron-builder usually handles this.
    # Since we are running 'pnpm build' which runs vite and esbuild, 
    # the output is in 'dist' and 'dist-electron'.

    makeWrapper ${lib.getExe electron} $out/bin/milkup \
      --add-flags $out/share/milkup/dist-electron/main/index.js \
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --inherit-argv0

    # Install icons and desktop file
    install -Dm644 src/renderer/public/logo.svg $out/share/icons/hicolor/scalable/apps/milkup.svg

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "milkup";
      exec = "milkup %U";
      icon = "milkup";
      desktopName = "milkup";
      comment = "A Markdown editor built with Milkup core and Vue.js";
      categories = [
        "Office"
        "TextEditor"
      ];
      terminal = false;
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/Auto-Plugin/milkup"
      "--use-github-releases"
    ];
  };

  meta = with lib; {
    description = "A Markdown editor built with Milkup core and Vue.js";
    homepage = "https://github.com/Auto-Plugin/milkup";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "milkup";
  };
}
