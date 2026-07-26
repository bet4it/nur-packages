{
  lib,
  python314Packages,
  fetchFromGitHub,
}:

python314Packages.buildPythonApplication rec {
  pname = "fast-resume";
  version = "2.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    tag = "v${version}";
    hash = "sha256-gZjacCyTzSrCQdlaEfvlOQPHFURXgLdzyhFBT0KcxWw=";
  };

  build-system = with python314Packages; [
    hatchling
  ];

  dependencies = with python314Packages; [
    textual
    rich
    click
    humanize
    orjson
  ] ++ lib.optionals (python314Packages ? textual-image) [
    python314Packages.textual-image
  ] ++ lib.optionals (python314Packages ? tantivy) [
    python314Packages.tantivy
  ];

  dontCheckRuntimeDeps = true;

  meta = with lib; {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = licenses.mit;
    mainProgram = "fr";
  };
}
