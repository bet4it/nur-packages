{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.14.4";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-MkhUnRIIWVS70KCuKj0GUhwfT7m/yYok+8ExNmkaSpE=";
  };

  cargoHash = "sha256-bf8kDF6QIvG2ckKO1UGVCw2QCtArCrE0KKkEPrgjvkg=";

  dontCargoUseSystemLibs = true;

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
