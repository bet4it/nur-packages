{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  glib,
  gtk3,
  libayatana-appindicator,
  desktop-file-utils,
  makeDesktopItem,
  copyDesktopItems,
  fontconfig,
  freetype,
  dbus,
  openssl,
  libxkbcommon,
  wayland,
  libxcb,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libGL,
  vulkan-loader,
  wrapGAppsHook3,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "nyaterm";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "nyakang";
    repo = "nyaterm";
    rev = "v${version}";
    hash = "sha256-epVnUWbMCY86hxBD6zSQQ+l0o9GcXKWzgRY23NY6n5A=";
  };

  cargoHash = "sha256-jm+DuN+NfU0zHOzbyKhi2k1RGfH5jyf81xKlnPKPZaM=";

  cargoBuildFlags = [
    "-p"
    "nyaterm-app"
    "-p"
    "nyaterm-mcp"
    "-p"
    "nyaterm-rdp-helper"
    "-p"
    "nyaterm-vnc-helper"
  ];

  nativeBuildInputs = [
    pkg-config
    cmake
    wrapGAppsHook3
    copyDesktopItems
    desktop-file-utils
  ];

  buildInputs = [
    glib
    gtk3
    libayatana-appindicator
    fontconfig
    freetype
    dbus
    openssl
    libxkbcommon
    wayland
    libxcb
    libX11
    libXcursor
    libXi
    libXrandr
  ];

  appendRunpaths = [
    (lib.makeLibraryPath [
      libGL
      vulkan-loader
      wayland
      libxkbcommon
      libX11
      libXcursor
      libXi
      libXrandr
      libayatana-appindicator
    ])
  ];

  postPatch = ''
    libappindicatorSys=$(find $cargoDepsCopy -path '*/libappindicator-sys-*/src/lib.rs' -print -quit)
    if [ -n "$libappindicatorSys" ]; then
      substituteInPlace "$libappindicatorSys" \
        --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
    fi
  '';

  doCheck = false;

  postInstall = ''
    for size in 32x32 64x64 128x128 256x256 512x512; do
      install -Dm644 "crates/nyaterm-app/resources/icons/$size.png" \
        "$out/share/icons/hicolor/$size/apps/nyaterm.png"
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "nyaterm";
      desktopName = "NyaTerm";
      comment = "Native GPUI terminal and SSH client";
      exec = "nyaterm %U";
      icon = "nyaterm";
      startupWMClass = "nyaterm";
      terminal = false;
      categories = [
        "Development"
        "TerminalEmulator"
        "Network"
      ];
      mimeTypes = [
        "x-scheme-handler/nyaterm"
        "x-scheme-handler/ssh"
        "x-scheme-handler/telnet"
      ];
      startupNotify = true;
    })
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/nyakang/nyaterm"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "A modern remote terminal workspace built with GPUI and Rust";
    homepage = "https://github.com/nyakang/nyaterm";
    changelog = "https://github.com/nyakang/nyaterm/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "nyaterm";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
