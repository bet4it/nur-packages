{
  lib,
  flutter338,
  fetchFromGitHub,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  gst_all_1,
  keybinder3,
  libayatana-appindicator,
}:

flutter338.buildFlutterApplication rec {
  pname = "kelivo";
  version = "1.1.15";

  src = fetchFromGitHub {
    owner = "Chevey339";
    repo = "kelivo";
    rev = "v${version}";
    hash = "sha256-rORMY8ATQK95a7HiV7pVM1Ok7ot0jCJMRGT47kFEJGE=";
  };

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    gst_all_1.gst-plugins-base
    gst_all_1.gstreamer
    keybinder3
    libayatana-appindicator
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "com.psyche.kelivo";
      exec = "kelivo";
      icon = "com.psyche.kelivo";
      desktopName = "Kelivo";
      startupWMClass = "com.psyche.kelivo";
      comment = "An LLM chat client";
      categories = [
        "Network"
        "Chat"
      ];
    })
  ];

  postInstall = ''
    install -Dm644 assets/app_icon.png \
      $out/share/icons/hicolor/512x512/apps/com.psyche.kelivo.png
    ln -s com.psyche.kelivo.png \
      $out/share/icons/hicolor/512x512/apps/kelivo.png
  '';

  meta = {
    description = "LLM chat client";
    homepage = "https://github.com/Chevey339/kelivo";
    license = lib.licenses.agpl3Only;
    mainProgram = "kelivo";
    platforms = lib.platforms.linux;
  };
}
