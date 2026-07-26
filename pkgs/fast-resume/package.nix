{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-gZjacCyTzSrCQdlaEfvlOQPHFURXgLdzyhFBT0KcxWw=";
  };

  cargoHash = "sha256-XPyrVqS408RfE9Kbx25krpGSf08hHCv6EE6jBa2vG4g=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
