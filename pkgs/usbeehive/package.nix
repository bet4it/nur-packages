{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  systemdLibs,
}:

rustPlatform.buildRustPackage rec {
  pname = "usbeehive";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-OQtAZnoQOQWlMY51JoaGDPHXjYtwHXu4cnzuEzcblWU=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    systemdLibs
  ];

  cargoHash = "sha256-wiIc7ofX57nL2931P/tIom3SibmuuFqShXG4r/FKzEA=";

  meta = with lib; {
    description = "A brief description of your package";
    homepage = "https://github.com/abrauchli/usbeehive";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "usbeehive";
  };
}
