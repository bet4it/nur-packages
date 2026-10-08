{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.13.2";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-WU7ZRaCk9FDkm+mx1KKkvDxINC+cVvxqv9zuxcwdXe8=";
  };

  cargoHash = "sha256-S29PAAaF7907/HhgrFeer+QOaEDcco6+fEBIVc02L60=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
