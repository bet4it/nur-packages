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
  version = "2.0.30";

  src = fetchFromGitHub {
    owner = "AnalyseDeCircuit";
    repo = "oxideterm";
    tag = "v${version}";
    hash = "sha256-UK8FntyuaNmzkKrz/4SMRtKmjXCBog0A0b4L4HrKpto=";
  };

  cargoHash = "sha256-CUo05Len1KZMhjcEfLPz/e/ONyp+yM7Wvh7S5Fhcve4=";

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

    install -Dm644 crates/oxideterm-gpui-app/resources/icons/32x32.png $out/share/icons/hicolor/32x32/apps/com.oxideterm.app.png
    install -Dm644 crates/oxideterm-gpui-app/resources/icons/64x64.png $out/share/icons/hicolor/64x64/apps/com.oxideterm.app.png
    install -Dm644 crates/oxideterm-gpui-app/resources/icons/128x128.png $out/share/icons/hicolor/128x128/apps/com.oxideterm.app.png
    install -Dm644 crates/oxideterm-gpui-app/resources/icons/128x128@2x.png $out/share/icons/hicolor/256x256/apps/com.oxideterm.app.png
    install -Dm644 crates/oxideterm-gpui-app/resources/icons/icon.png $out/share/icons/hicolor/512x512/apps/com.oxideterm.app.png

    for size in 32x32 64x64 128x128 256x256 512x512; do
      ln -s com.oxideterm.app.png $out/share/icons/hicolor/$size/apps/oxideterm.png
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "com.oxideterm.app";
      exec = "oxideterm-native %U";
      icon = "com.oxideterm.app";
      desktopName = "OxideTerm";
      comment = "Local-first SSH workspace with terminal, SFTP, forwarding, and BYOK AI";
      categories = [
        "Development"
        "Network"
        "TerminalEmulator"
      ];
      startupWMClass = "com.oxideterm.app";
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
