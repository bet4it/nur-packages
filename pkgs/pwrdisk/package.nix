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
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "pwrdisk";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "pwrdrvr";
    repo = "PwrDisk";
    tag = "v${version}";
    hash = "sha256-J84QvYQ/6SUvT4gologpfLLB/sd7XAgBU0wrkDAlVso=";
  };

  cargoHash = "sha256-fQhYftpTq8pO2SlK6+jZMmgJzcy7w99qnG1gvYz+LfI=";

  cargoBuildFlags = [
    "--ignore-rust-version"
    "-p"
    "disktree-app"
    "--bin"
    "pwrdisk"
    "-p"
    "disktree-scan"
    "--bin"
    "disktree-scan"
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

  env = {
    PWRDISK_SOURCE_SHA = "e6e2117da1b4e7450bfed6b2a67fa2e352f08de6";
  };

  doCheck = false;

  postInstall = ''
    install -Dm644 assets/disktree.svg $out/share/icons/hicolor/scalable/apps/pwrdisk.svg
    install -Dm644 assets/disktree.svg $out/share/pixmaps/pwrdisk.svg

    install -d $out/share/applications
    sed -e "s|@BINDIR@|$out/bin|" -e "s|@VERSION@|${version}|" \
      packaging/pwrdisk.desktop.in > $out/share/applications/pwrdisk.desktop

    wrapProgram $out/bin/pwrdisk \
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
      "--url=https://github.com/pwrdrvr/PwrDisk"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "GPUI treemap explorer for disk usage, in Omarchy's visual language";
    homepage = "https://github.com/pwrdrvr/PwrDisk";
    changelog = "https://github.com/pwrdrvr/PwrDisk/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pwrdisk";
    platforms = lib.platforms.linux;
  };
}
