{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.12.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-IApxU7smV/4lmpbdrCW8rQcsuJ/G2VRVo8pxWQoMKp8=";
  };

  cargoHash = "sha256-0DyS7NyO+X2buVvI5eAZ9UOXTsy8S79zkm4nW/V2FpI=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
