{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  pkg-config,
  protobuf,
  fontconfig,
  openssl,
  sqlite,
  zlib,
  zstd,
  glib,
  alsa-lib,
  libxkbcommon,
  wayland,
  libxcb,
  libX11,
  libXext,
  vulkan-loader,
  dbus,
  systemdLibs,
  gst_all_1,
  libkrb5,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "oxideterm";
  version = "2.0.24";

  src = fetchFromGitHub {
    owner = "AnalyseDeCircuit";
    repo = "oxideterm";
    tag = "v${version}";
    hash = "sha256-TI0cRiCL1AuKUn+dE9Zu/hH+S+1ey8hH+MK7hKGKwYA=";
  };

  cargoHash = "sha256-8xUyAmQEuTcnr63ejnGtyNTNIy4/VhGFbf+DQ/mqsNc=";

  cargoBuildFlags = [
    "-p"
    "oxideterm-gpui-app"
    "--bin"
    "oxideterm-native"
    "-p"
    "oxideterm-cli"
    "--bin"
    "oxideterm"
  ];

  doCheck = false;

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
    makeWrapper
    copyDesktopItems
    writableTmpDirAsHomeHook
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    fontconfig
    openssl
    sqlite
    zlib
    zstd
    glib
    alsa-lib
    libxkbcommon
    wayland
    libxcb
    libX11
    libXext
    vulkan-loader
    dbus
    systemdLibs
    libkrb5
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
  ];

  postInstall = ''
    mv $out/bin/oxideterm-native $out/bin/oxideterm-native.unwrapped
    makeWrapper $out/bin/oxideterm-native.unwrapped $out/bin/oxideterm-native \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          libxkbcommon
          wayland
        ]
      } \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${
        lib.makeSearchPath "lib/gstreamer-1.0" [
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
        ]
      }

    ln -s $out/bin/oxideterm-native $out/bin/OxideTerm
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "oxideterm";
      exec = "oxideterm-native %U";
      icon = "oxideterm";
      desktopName = "OxideTerm";
      comment = "Local-first SSH workspace with terminal, SFTP, forwarding, and BYOK AI";
      categories = [
        "Development"
        "Network"
        "TerminalEmulator"
      ];
      startupWMClass = "OxideTerm";
    })
  ];

  meta = {
    description = "Local-first SSH workspace with terminal, SFTP, forwarding, and BYOK AI";
    homepage = "https://github.com/AnalyseDeCircuit/oxideterm";
    changelog = "https://github.com/AnalyseDeCircuit/oxideterm/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "oxideterm-native";
    platforms = lib.platforms.linux;
  };
}
