{
  lib,
  stdenv,
  darwin,
  rustPlatform,
  fetchFromGitHub,
  autoPatchelfHook,
  cmake,
  ncurses,
  pkg-config,
  gcc-unwrapped,
  fontconfig,
  libGL,
  vulkan-loader,
  libxkbcommon,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libxcb,
  wayland,
  shaderc,
  nix-update-script,
  ...
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rio";
  version = "0.5.15";

  src = fetchFromGitHub {
    owner = "raphamorim";
    repo = "rio";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fDIJhL8HvZogN8agpY7Ywe++/7VrtEYMCokC/20A3aA=";
  };

  cargoHash = "sha256-anebUzh3SYYZtkiVSwxBpyUQJd5PZfgNCwlUOMcC/Oc=";

  cargoBuildFlags = [
    "-p"
    "rioterm"
  ];

  buildNoDefaultFeatures = true;
  buildFeatures = [
    "wayland"
    "x11"
  ];

  outputs = [
    "out"
    "terminfo"
  ];

  nativeBuildInputs =
    [
      rustPlatform.bindgenHook
      ncurses
      shaderc
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      cmake
      pkg-config
      autoPatchelfHook
    ];

  buildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      (lib.getLib gcc-unwrapped)
      fontconfig
      libGL
      libxkbcommon
      vulkan-loader
      libX11
      libXcursor
      libXi
      libXrandr
      libxcb
      wayland
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      darwin.libutil
    ];

  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    (lib.getLib gcc-unwrapped)
    fontconfig
    libGL
    libxkbcommon
    vulkan-loader
    libX11
    libXcursor
    libXi
    libXrandr
    libxcb
    wayland
  ];

checkType = "debug";
  doCheck = false;

  postInstall =
    ''
      install -D -m 644 misc/rio.desktop -t \
        $out/share/applications
      install -D -m 644 misc/logo.svg \
        $out/share/icons/hicolor/scalable/apps/rio.svg

      install -dm 755 "$terminfo/share/terminfo/r/"
      tic -xe xterm-rio,rio,rio-direct -o "$terminfo/share/terminfo" misc/rio.terminfo
      mkdir -p $out/nix-support
      echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/Applications/
      cp -R misc/osx/Rio.app/ $out/Applications/
      mkdir -p $out/Applications/Rio.app/Contents/MacOS/
      ln -s $out/bin/rio $out/Applications/Rio.app/Contents/MacOS/
    '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/raphamorim/rio"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "A hardware-accelerated GPU terminal emulator powered by WebGPU";
    longDescription = ''
      Rio terminal is a hardware-accelerated GPU terminal emulator,
      focusing to run in desktops and browsers. The supported platforms
      currently consist of BSD, Linux, MacOS and Windows.
    '';
    homepage = "https://github.com/raphamorim/rio";
    changelog = "https://github.com/raphamorim/rio/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.unix;
    mainProgram = "rio";
  };
})
