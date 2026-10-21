{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
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
  openssl,
  dbus,
  nix-update-script,
}:

let
  desktopItem = makeDesktopItem {
    name = "Fulgur";
    exec = "Fulgur %F";
    icon = "app.fulgur.fulgur";
    desktopName = "Fulgur";
    comment = "Lightning-fast, fully themable, multiplatform text editor with secure file synchronization";
    categories = [
      "Development"
      "TextEditor"
    ];
    mimeTypes = [
      "text/plain"
      "text/markdown"
      "text/x-markdown"
    ];
    startupWMClass = "Fulgur";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "fulgur";
  version = "0.14.0";

  src = fetchFromGitHub {
    owner = "fulgur-app";
    repo = "Fulgur";
    rev = "v${version}";
    hash = "sha256-eYhhKqRdyg1HSpXiS8bEsEql8uEAsYJi2Gsh6tvLe5U=";
  };

  cargoHash = "sha256-wxIgfDWsUhMazfMbg67/hmMtLvk2gES0vD6MKZfLVcs=";

  cargoBuildFlags = [ "--ignore-rust-version" ];

  nativeBuildInputs = [
    pkg-config
    cmake
    makeWrapper
    copyDesktopItems
    rustPlatform.bindgenHook
  ];

  dontUseCmakeConfigure = true;

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
    openssl
    dbus
  ];

  desktopItems = [ desktopItem ];

  postPatch = ''
    # Remove upstream's linker override (clang / mold) to use Nix's toolchain
    rm -f .cargo/config.toml
  '';

  env = {
    RUST_MIN_STACK = "16777216";
    OPENSSL_NO_VENDOR = "1";
  };

  doCheck = false;

  postInstall = ''
    install -Dm644 resources/linux/app.fulgur.fulgur.metainfo.xml $out/share/metainfo/app.fulgur.fulgur.metainfo.xml

    for size in 16 32 48 64 128 256 512; do
      install -Dm644 assets/icon_''${size}.png $out/share/icons/hicolor/''${size}x''${size}/apps/app.fulgur.fulgur.png
      ln -s app.fulgur.fulgur.png $out/share/icons/hicolor/''${size}x''${size}/apps/Fulgur.png
      ln -s app.fulgur.fulgur.png $out/share/icons/hicolor/''${size}x''${size}/apps/fulgur.png
    done
    install -Dm644 assets/icon.png $out/share/pixmaps/app.fulgur.fulgur.png
    ln -s app.fulgur.fulgur.png $out/share/pixmaps/Fulgur.png
    ln -s app.fulgur.fulgur.png $out/share/pixmaps/fulgur.png

    # Also provide a lowercase symlink for convenience
    ln -s Fulgur $out/bin/fulgur

    wrapProgram $out/bin/Fulgur \
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
      "--url=https://github.com/fulgur-app/Fulgur"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Lightning-fast, fully themable, multiplatform text editor with secure file synchronization";
    homepage = "https://fulgur.app";
    changelog = "https://github.com/fulgur-app/Fulgur/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "Fulgur";
    platforms = lib.platforms.linux;
  };
}
