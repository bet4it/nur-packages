{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  dbus,
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
  version = "1.0.4";

  src = fetchFromGitHub {
    owner = "mebishp";
    repo = "meku";
    rev = "v${version}";
    hash = "sha256-CKHgh6K6vzKzD8bArmw/GojV41TqQ8RQzO5lSV5xNmc=";
  };

  cargoHash = "sha256-Fz8oqgzAQkhKoM/x7ve05aCm8p1PBqGVlNyVFt3pezM=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    dbus
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
          dbus
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
