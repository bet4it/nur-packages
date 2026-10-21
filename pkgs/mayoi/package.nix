{
  lib,
  stdenv,
  buildGo127Module,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  gtk3,
  glib,
  cairo,
  gdk-pixbuf,
  libepoxy,
  pango,
  atk,
  libx11,
  libsecret,
  libGL,
  libayatana-appindicator,
  libpulseaudio,
  alsa-lib,
  nix-update-script,
}:

let
  desktopItem = makeDesktopItem {
    name = "mayoi";
    desktopName = "Mayoi";
    exec = "mayoi %F";
    icon = "mayoi";
    comment = "A small, fast code editor";
    categories = [
      "Development"
      "TextEditor"
    ];
    mimeTypes = [
      "text/plain"
      "text/markdown"
      "text/x-markdown"
    ];
    startupWMClass = "Mayoi";
  };

  # MyGo pins libghostty-vt to commit befcdfd2c3a1, which defines symbols
  # like ghostty_terminal_compress. The libghostty-vt in nixpkgs is an older
  # snapshot (commit 22d13172) where those symbols are missing, causing runtime
  # ABI check failure. Hence we use the upstream pinned prebuilt library.
  ghosttyVt = fetchurl {
    x86_64-linux = {
      url = "https://github.com/egoist/mygo/releases/download/libghostty-vt-befcdfd2c3a1/libghostty-vt-linux-amd64.so";
      hash = "sha256-nc2K8N5nd4pWH0NstnOp+xc4vo+gCEna1JYGuu0eV9c=";
    };
    aarch64-linux = {
      url = "https://github.com/egoist/mygo/releases/download/libghostty-vt-befcdfd2c3a1/libghostty-vt-linux-arm64.so";
      hash = "sha256-+xY/jxIyBpVnUfHE8DA7QImVE7fcFxqKuNhbp81UG8A=";
    };
  }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
buildGo127Module rec {
  pname = "mayoi";
  version = "0.11.5";

  src = fetchFromGitHub {
    owner = "sorrycc";
    repo = "Mayoi";
    rev = "v${version}";
    hash = "sha256-zZebUCHSQSzhqMw68RhwuNdz6KwS8/rJrLhQ0DHAIPo=";
  };

  vendorHash = "sha256-1KdQXegxK8jQK1CgoaXqBDO8FMTO7H9TMGW4WPBpPhY=";

  subPackages = [ "cmd/mayoi" ];

  tags = [ "mygo_noinspector" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/egoist/mygo.production=1"
    "-X github.com/egoist/mygo.packageName=Mayoi"
    "-X github.com/egoist/mygo.packageVersion=${version}"
    "-X github.com/egoist/mygo.packageIdentifier=dev.mayoi.editor"
  ];

  doCheck = false;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
  ];

  buildInputs = [
    gtk3
    glib
    cairo
    gdk-pixbuf
    libepoxy
    pango
    atk
    libx11
    libsecret
    libGL
    libayatana-appindicator
    libpulseaudio
    alsa-lib
    stdenv.cc.cc.lib
  ];

  desktopItems = [ desktopItem ];

  postInstall = ''
    install -Dm644 resources/icon.png $out/share/icons/hicolor/1024x1024/apps/mayoi.png
    ln -s mayoi.png $out/share/icons/hicolor/1024x1024/apps/Mayoi.png

    install -Dm644 resources/icon.png $out/share/pixmaps/mayoi.png
    ln -s mayoi.png $out/share/pixmaps/Mayoi.png

    ln -s mayoi $out/bin/Mayoi

    mkdir -p $out/lib/mayoi
    install -Dm755 ${ghosttyVt} $out/lib/mayoi/libghostty-vt.so

    wrapProgram $out/bin/mayoi \
      --set MYGO_GHOSTTY_VT $out/lib/mayoi/libghostty-vt.so \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          gtk3
          glib
          cairo
          gdk-pixbuf
          libepoxy
          pango
          atk
          libx11
          libsecret
          libGL
          libayatana-appindicator
          libpulseaudio
          alsa-lib
        ]
      }
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/sorrycc/Mayoi"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Small, fast code editor written in Go with native GPU UI via MyGo";
    homepage = "https://github.com/sorrycc/Mayoi";
    changelog = "https://github.com/sorrycc/Mayoi/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "mayoi";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
