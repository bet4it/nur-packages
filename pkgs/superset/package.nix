{
  lib,
  fetchurl,
  appimageTools,
  nix-update-script,
}:

let
  pname = "superset";
  version = "1.5.9";

  src = fetchurl {
    name = "superset-${version}-x86_64.AppImage";
    url = "https://github.com/superset-sh/superset/releases/download/desktop-v${version}/Superset-x86_64.AppImage";
    hash = "sha256-ocdMdeqTRRMtpkIDEKez/EEGnt80F/dT+Wht0wSoPnQ=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/@supersetdesktop.desktop $out/share/applications/superset.desktop
    substituteInPlace $out/share/applications/superset.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=superset --no-sandbox %U' \
      --replace-fail 'Icon=@supersetdesktop' 'Icon=superset'

    install -Dm444 ${appimageContents}/@supersetdesktop.png \
      $out/share/icons/hicolor/512x512/apps/superset.png
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--use-github-releases"
      "--version-regex=^desktop-v(.*)$"
    ];
  };

  meta = {
    description = "Desktop app that helps manage and run coding agents";
    homepage = "https://github.com/superset-sh/superset";
    changelog = "https://github.com/superset-sh/superset/releases/tag/desktop-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "superset";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
