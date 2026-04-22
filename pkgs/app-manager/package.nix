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
  squashfsTools,
  dwarfs,
  zsync2,
  procps,
  coreutils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "app-manager";
  version = "3.5.2";

  src = fetchFromGitHub {
    owner = "kem-a";
    repo = "AppManager";
    rev = "v${finalAttrs.version}";
    hash = "sha256-tC4kQLjlU/TzejFDAPn3WuaVV6LoFiGh4sSaEbibxFA=";
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
