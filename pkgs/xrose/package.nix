{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  protobuf,
  makeWrapper,
  fontconfig,
  openssl,
  zstd,
  sqlite,
  libgbm,
  libxkbcommon,
  wayland,
  libxcb,
  libX11,
  libXrandr,
  pipewire,
  libGL,
  vulkan-loader,
  xray,
  sing-box,
  systemd,
  polkit,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "xrose";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "zuoxinyu";
    repo = "xrose";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6h3uGNW/e5qSY9iTnsgBLGA/n5+OQ5BQlESD5rRJqFM=";
  };

  # The lockfile pins git dependencies (EasyTier) and in-tree path patches
  # (vendor/), so cargoHash goes through fetchCargoVendor, which vendors both.
  cargoHash = "sha256-BkclzgM5U/IZxEyiIh2PbqV6fl84jp54dSwkCmAOHFc=";

  # Tests want a display, network access and writable $HOME.
  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    # protoc, required by EasyTier's prost-build codegen.
    protobuf
    # bindgen, required by pipewire-sys.
    rustPlatform.bindgenHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    fontconfig
    libxkbcommon
    wayland
    libxcb
    libX11
    libXrandr
    # Screen capture backend (xcap).
    pipewire
    # wgpu's EGL backend (khronos-egl).
    libGL
    zstd
    # libsqlite3-sys resolves the system sqlite.
    sqlite
    # libgbm, required by the Wayland capture path (libwayshot).
    libgbm
  ];

  postInstall = ''
    # Xrose discovers its proxy cores on PATH, and GPUI loads the Vulkan
    # implementation dynamically, so both need to be wired up here. The
    # helper controls (start/stop/install) shell out to systemctl and pkexec.
    for bin in xrose-app xrose-cli; do
      mv $out/bin/$bin $out/bin/$bin.unwrapped
      makeWrapper $out/bin/$bin.unwrapped $out/bin/$bin \
        --prefix PATH : ${lib.makeBinPath [
          xray
          sing-box
          systemd
          polkit
        ]} \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            libGL
            vulkan-loader
            libxkbcommon
            wayland
            libX11
            libXrandr
            libxcb
          ]
        }
    done

    install -Dm644 crates/xrose-app/assets/io.xrose.Xrose.desktop $out/share/applications/io.xrose.Xrose.desktop
    install -Dm644 crates/xrose-app/assets/icons/xrose.png $out/share/icons/hicolor/256x256/apps/xrose.png
    install -Dm644 LICENSE $out/share/licenses/xrose/LICENSE
  '';

  meta = {
    description = "Xray and sing-box desktop client";
    homepage = "https://github.com/zuoxinyu/xrose";
    changelog = "https://github.com/zuoxinyu/xrose/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "xrose-app";
    platforms = lib.platforms.linux;
  };
})
