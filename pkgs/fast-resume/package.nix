{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.7.1";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-QMxTcvg5TkMnZ60VRGrqybey419UASwa9MYRhqxdmM8=";
  };

  cargoHash = "sha256-dFtMz2fwGGa9Q1j3vJ9bfSQOlOThLQmEZfpXEtAOoJ8=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
