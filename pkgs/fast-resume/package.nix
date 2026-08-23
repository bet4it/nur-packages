{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.11.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-4vX9wOQAcR2YyQjgHNO4h1WDofOw4bsXNwreExkQmhc=";
  };

  cargoHash = "sha256-Z2bsIydHLV4Nao6/VnYwLuYFD56z4WHxRLkVhFcPZz4=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
