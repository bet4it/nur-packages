{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  systemdLibs,
}:

rustPlatform.buildRustPackage rec {
  pname = "usbeehive";
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "abrauchli";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-zaGUIs/A6UXlsK8uSsMrsdTzQFfCDpsEmJB+lz2O7Pg=";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    systemdLibs
  ];

  cargoHash = "sha256-4JO9WaVYvBBCt3hVdigMhXrtVOM5t7ZEvVgsOESTVhw=";

  meta = with lib; {
    description = "A brief description of your package";
    homepage = "https://github.com/abrauchli/usbeehive";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
    mainProgram = "usbeehive";
  };
}
