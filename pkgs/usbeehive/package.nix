{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  systemdLibs,
}:

rustPlatform.buildRustPackage rec {
  pname = "usbeehive";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-TShsv/1zn3/0418ubljUmPsdQgSaiN3uaQjMOnHZTYU=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    systemdLibs
  ];

  cargoHash = "sha256-+Gn3jfaVuJxzjsllKIja41duSkK05X/X/PaSJPS2qwE=";

  meta = with lib; {
    description = "A brief description of your package";
    homepage = "https://github.com/abrauchli/usbeehive";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "usbeehive";
  };
}
