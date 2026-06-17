{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  systemdLibs,
}:

rustPlatform.buildRustPackage rec {
  pname = "usbeehive";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-5aqEqt0zwzG4O+roq0p4vs59z7s2ERPE+FzyW9waegw=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    systemdLibs
  ];

  cargoHash = "sha256-YX72/E1N59U6EU54SWpL8Ew/eMelAjnBF7xqpLYCNIo=";

  meta = with lib; {
    description = "A brief description of your package";
    homepage = "https://github.com/abrauchli/usbeehive";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "usbeehive";
  };
}
