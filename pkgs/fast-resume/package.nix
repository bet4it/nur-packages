{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.11.2";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-w/UxbPOBNQL9RC7KD6E1//uutUOlUYEBVFG20dLAwtI=";
  };

  cargoHash = "sha256-erbXhm/fzNNy+wyf0LLO/H+Jr+ftiRj12RCwqvDLxyg=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
