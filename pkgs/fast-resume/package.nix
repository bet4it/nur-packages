{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.11.1";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-SFfqx8XZTV/p+NBt+Tk5Th41OCzXx7AGaGmK421oBiE=";
  };

  cargoHash = "sha256-+/7RaQ9PTlBat2t6usX0X5uW47esiZ7MONNUsLF4dWA=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
