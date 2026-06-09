{
  lib,
  stdenv,
  fetchFromGitHub,
  glib,
  usbeehive,
}:

stdenv.mkDerivation rec {
  pname = "gnome-shell-extension-usbee";
  version = "2.3.1";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = "usbee";
    rev = "v${version}";
    hash = "sha256-BEYBUEy1LU+G9TDC78ytAXk0LCNdqv1TyEj3Y93awLk=";
  };

  nativeBuildInputs = [
    glib
  ];

  propagatedUserEnvPkgs = [
    usbeehive
  ];

  buildPhase = ''
    runHook preBuild
    glib-compile-schemas --strict usbee@bitcreed.us/schemas
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/gnome-shell/extensions"
    cp -r "usbee@bitcreed.us" "$out/share/gnome-shell/extensions/"
    runHook postInstall
  '';

  passthru = {
    extensionUuid = "usbee@bitcreed.us";
    extensionPortalSlug = "usbee";
    requiredPackages = [
      usbeehive
    ];
  };

  meta = {
    description = "GNOME Quick Settings indicator for USB and USB-C diagnostics";
    longDescription = "USBee mounts a GNOME Quick Settings tile for USB and USB-C diagnostics and reads all device state from the usbeehive daemon over D-Bus.";
    homepage = "https://github.com/abrauchli/usbee";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };
}
