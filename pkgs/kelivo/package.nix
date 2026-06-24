{
  lib,
  flutter344,
  fetchFromGitHub,
  callPackage,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  gst_all_1,
  keybinder3,
  libayatana-appindicator,
}:

flutter344.buildFlutterApplication rec {
  pname = "kelivo";
  version = "1.1.17";

  src = fetchFromGitHub {
    owner = "Chevey339";
    repo = "kelivo";
    rev = "v${version}";
    hash = "sha256-vCXZsZDwRu9v1uHWjpg8kcrTQgHu80Bnek5Mzl+ncH4=";
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

  passthru.updateScript = lib.getExe (callPackage ./update.nix { });

  meta = {
    description = "LLM chat client";
    homepage = "https://github.com/Chevey339/kelivo";
    license = lib.licenses.agpl3Only;
    mainProgram = "kelivo";
    platforms = lib.platforms.linux;
  };
}
