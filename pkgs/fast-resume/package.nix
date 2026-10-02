{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.13.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-h5/aLV7tbEFnrD4fVVZNmVmo1mZwTwaTLB+rMPQRqw0=";
  };

  cargoHash = "sha256-ouJZ6j3PT3NMRb9QKP2t0Cd+krcjXTSF5Fcgu4ZECZs=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
