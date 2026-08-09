{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.9.4";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-W9f5Q7D95Ig4DYkbSIWZa+j6RyxuhwEn+J2AUahPLg8=";
  };

  cargoHash = "sha256-ul6jrlAPv9bEPGKz3OMP3j1bU9zLKpV55/SZ64cUVGE=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
