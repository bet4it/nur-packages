{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "fast-resume";
  version = "2.14.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-J8KCli0q7BiUU1eXbbWfkYWvKaNgMY0GtfG+nwb8qOg=";
  };

  cargoHash = "sha256-2TaKJfNGbhzB17KUFyJp27DBRt3S8QnpqS8xvdZPjIs=";

  meta = {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = lib.licenses.mit;
    mainProgram = "fr";
  };
}
