{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  systemdLibs,
}:

rustPlatform.buildRustPackage rec {
  pname = "usbeehive";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-zxSAJKM6tqDyFGHLvxHdBfrtgPGiINlqI9i//3LIQfI=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    systemdLibs
  ];

  cargoHash = "sha256-adJGVPXBnHXlGx+SLjMcbjwmr5V/b/+n6qbtgU+Dyqk=";

  meta = with lib; {
    description = "A brief description of your package";
    homepage = "https://github.com/abrauchli/usbeehive";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "usbeehive";
  };
}
