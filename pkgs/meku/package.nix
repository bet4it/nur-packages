{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  fontconfig,
  freetype,
  libGL,
  libxkbcommon,
  wayland,
  wayland-protocols,
  libxcb,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  vulkan-loader,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "meku";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "mebishp";
    repo = "meku";
    rev = "v${version}";
    hash = "sha256-1LSaZ+f5JfAOodpfih5Wr3Ij6RcVFvDy51oAeQa1RXA=";
  };

  cargoHash = "sha256-dC3Sg+Ud6ySJwD2zGNoD165ER1meRHexqnXDD0iTyfs=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    freetype
    libGL
    libxkbcommon
    wayland
    wayland-protocols
    libxcb
    libX11
    libXcursor
    libXi
    libXrandr
    vulkan-loader
  ];

  doCheck = false;

  postInstall = ''
    install -Dm644 packaging/meku.desktop $out/share/applications/meku.desktop
    install -Dm644 packaging/meku.svg $out/share/icons/hicolor/scalable/apps/meku.svg
    install -Dm644 packaging/meku-1024.png $out/share/icons/hicolor/1024x1024/apps/meku.png

    wrapProgram $out/bin/meku \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          libxkbcommon
          wayland
          libGL
          libX11
          libxcb
          libXcursor
          libXi
          libXrandr
          fontconfig
          freetype
        ]
      }
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/mebishp/meku"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "GPU-accelerated native markdown editor for folders of notes";
    homepage = "https://github.com/mebishp/meku";
    changelog = "https://github.com/mebishp/meku/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "meku";
    platforms = lib.platforms.linux;
  };
}
