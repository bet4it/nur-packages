{
  lib,
  python314Packages,
  fetchFromGitHub,
}:

python314Packages.buildPythonApplication rec {
  pname = "fast-resume";
  version = "1.18.0";

  src = fetchFromGitHub {
    owner = "angristan";
    repo = "fast-resume";
    rev = "v${version}";
    hash = "sha256-0r5g2zMELFVHjVbujLJONSquCope3fxctWStNnN4nEs=";
  };

  format = "pyproject";

  nativeBuildInputs = with python314Packages; [
    hatchling
  ];

  propagatedBuildInputs = with python314Packages; [
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

  # Skip runtime dep version check (rich<14.3.2 vs nixpkgs 14.3.3)
  dontCheckRuntimeDeps = true;

  pythonRelaxDeps = [
    "rich"
  ];

  meta = with lib; {
    description = "Fuzzy finder for coding agent session history";
    homepage = "https://github.com/angristan/fast-resume";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "fast-resume";
  };
}