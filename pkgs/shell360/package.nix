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
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "nashaofu";
    repo = "shell360";
    rev = "v${version}";
    hash = "sha256-qpJaUO8/CpmtSaSWwTiA0lLd32UM+LtjRkSWNNjccwE=";
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
    hash = "sha256-K8EJEq5tS1Xh5Ctup0BcYXw9mBL6vop5klq2yRiRX/Y=";
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
