{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pkg-config,
  openssl,
  glib,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  librsvg,
  pnpm_9,
  nodejs,
  pnpmConfigHook,
  wrapGAppsHook3,
  cargo-tauri,
  perl,
}:

rustPlatform.buildRustPackage rec {
  pname = "shell360";
  version = "0.1.19";

  src = fetchFromGitHub {
    owner = "nashaofu";
    repo = "shell360";
    rev = "v${version}";
    hash = "sha256-qY2ozTWnunSFoKGOx/BgG5I9BBYPh/VuK66dJMKZwFk=";
  };

  nativeBuildInputs = [
    pkg-config
    pnpm_9
    pnpmConfigHook
    nodejs
    wrapGAppsHook3
    cargo-tauri.hook
    perl
  ];

  buildInputs = [
    openssl
    glib
    gtk3
    libsoup_3
    webkitgtk_4_1
    librsvg
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_9;
    fetcherVersion = 3;
    hash = "sha256-2fV0hR/WY/ZuJPpTHR2nzTNtJvcQr1Hzv2lbIwGplIw=";
  };

  cargoHash = "sha256-wKRXhnsp1ox+0QED3mb+M/i2awQP+IDeOeAMOpZQR8Y=";

  postPatch = ''
    substituteInPlace src-tauri/tauri.conf.json \
      --replace '"createUpdaterArtifacts": true' '"createUpdaterArtifacts": false'
  '';

  doCheck = false;

  meta = {
    description = "A cross-platform SSH and SFTP client";
    homepage = "https://github.com/nashaofu/shell360";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
    mainProgram = "shell360";
  };
}
