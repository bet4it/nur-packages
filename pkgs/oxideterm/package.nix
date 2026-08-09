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
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "oxideterm";
  version = "2.0.18";

  src = fetchFromGitHub {
    owner = "AnalyseDeCircuit";
    repo = "oxideterm";
    tag = "v${version}";
    hash = "sha256-CpzMIurLdWBoNgLO3hq+KcuemGMfVZ38o/Br2tPqRXg=";
  };

  cargoHash = "sha256-gjYFuxI1+rMUDPaPU/RqZuHs0JKIO8FllU5nXrvLH/Y=";

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
