{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  vala,
  gettext,
  wrapGAppsHook4,
  desktop-file-utils,
  glib,
  gtk4,
  libadwaita,
  json-glib,
  libgee,
  libsoup_3,
  glib-networking,
  libsecret,
  gnutls,
  squashfsTools,
  dwarfs,
  zsync2,
  procps,
  coreutils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "app-manager";
  version = "3.7.3";

  src = fetchFromGitHub {
    owner = "kem-a";
    repo = "AppManager";
    rev = "v${finalAttrs.version}";
    hash = "sha256-6l9MFZhlyc9F5ewigf09JX1q9aeoBipYulT56GoRpes=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    vala
    gettext
    wrapGAppsHook4
    desktop-file-utils
    glib
  ];

  buildInputs = [
    gtk4
    libadwaita
    json-glib
    libgee
    libsoup_3
    glib-networking
    libsecret
    gnutls
  ];

  mesonFlags = [
    "-Dbundle_dwarfs=false"
    "-Dbundle_zsync=false"
    "-Dbundle_unsquashfs=false"
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          squashfsTools
          dwarfs
          zsync2
          procps
          coreutils
          desktop-file-utils
          gtk4
        ]
      }
      --set APP_MANAGER_DWARFS_DIR ${dwarfs}/bin
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    desktop-file-validate $out/share/applications/com.github.AppManager.desktop
    test -x $out/bin/app-manager
    $out/bin/app-manager --version >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "GTK/libadwaita desktop utility for installing and updating AppImages";
    homepage = "https://github.com/kem-a/AppManager";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = [ ];
    mainProgram = "app-manager";
    platforms = lib.platforms.linux;
  };
})
