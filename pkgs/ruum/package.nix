{
  lib,
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
  zenity,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "ruum";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "JsonLee12138";
    repo = "Ruum";
    tag = "v${version}";
    hash = "sha256-b60WwuI9B2wKfkiiI/HoJlCm5QuyCkqXRWDbDarlG+M=";
  };

  cargoHash = "sha256-9TT+HAef7XTN2j0fifoN/G9AWeFYnjco9dqawUAKIeI=";

  cargoBuildFlags = [
    "--ignore-rust-version"
    "-p"
    "ruum-app"
    "--bin"
    "ruum"
    "-p"
    "ruum-scan"
    "--bin"
    "ruum-scan"
  ];

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
    install -Dm644 assets/ruum.svg $out/share/icons/hicolor/scalable/apps/ruum.svg
    install -Dm644 assets/ruum.svg $out/share/pixmaps/ruum.svg

    install -d $out/share/applications
    sed -e "s|@BINDIR@|$out/bin|" -e "s|@VERSION@|${version}|" \
      packaging/ruum.desktop.in > $out/share/applications/ruum.desktop

    wrapProgram $out/bin/ruum \
      --prefix PATH : ${lib.makeBinPath [ zenity ]} \
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
      "--url=https://github.com/JsonLee12138/Ruum"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Cross-platform treemap disk analyzer and cleanup companion";
    homepage = "https://github.com/JsonLee12138/Ruum";
    changelog = "https://github.com/JsonLee12138/Ruum/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ruum";
    platforms = lib.platforms.linux;
  };
}
