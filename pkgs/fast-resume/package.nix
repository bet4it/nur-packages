{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.14.5";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-aBHsc6N/+SRmB4r8L6FD5ld6Q6pVpm1IjTq21C8Ch4U=";
  };

  cargoHash = "sha256-3uxdr6vzcRIg4nL0dil1GBo0MCIzcD3rDSyQUuER/2w=";

  dontCargoUseSystemLibs = true;

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
