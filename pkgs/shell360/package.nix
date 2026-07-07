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
  pnpm_10,
  nodejs,
  pnpmConfigHook,
  wrapGAppsHook3,
  cargo-tauri,
  perl,
}:

rustPlatform.buildRustPackage rec {
  pname = "shell360";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "nashaofu";
    repo = "shell360";
    rev = "v${version}";
    hash = "sha256-/twcuN0rpCSJrqCPooq172Cr8pk4cDDKUM/qrv744N4=";
  };

  nativeBuildInputs = [
    pkg-config
    pnpm_10
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
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-rzxlq2mB7BI0miHx6qwJXotKj+THBzi+INB6FEyW+GA=";
  };

  cargoHash = "sha256-JEUvNUPt4iaZBZYKoAjNqXu78wLQPTAxEsg/8KkZ1ek=";

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
