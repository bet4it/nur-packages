{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_20,
  makeWrapper,
}:
let
  originalPackage = buildNpmPackage rec {
    pname = "claudecodeui";
    version = "1.29.5";

    src = fetchFromGitHub {
      owner = "siteboon";
      repo = "claudecodeui";
      rev = "v${version}";
      hash = "sha256-A0R8pYn211JkhIsLbklM0G46/7SchbU/sOwH5ZA7O3s=";
    };

    npmDepsHash = "sha256-k45V1Kt7J5gb59HkvGdVUJabEZczaBNAGHQpZDVCY6A=";

    buildInputs = [ nodejs_20 ];
    dontNpmBuild = false;

    meta = with lib; {
      description = "Use Claude Code, Cursor CLI or Codex on mobile and web with CloudCLI (aka Claude Code UI)";
      homepage = "https://github.com/siteboon/claudecodeui";
      license = licenses.gpl3Only;
      maintainers = [ ];
      mainProgram = "cloudcli";
    };
  };
in
originalPackage.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ makeWrapper ];

  postInstall = ''
        for bin in claude-code-ui cloudcli; do
          if [ -f "$out/bin/$bin" ]; then
            mv "$out/bin/$bin" "$out/bin/$bin.original"
            cat > "$out/bin/$bin" << 'WRAPPEREOF'
    #!/usr/bin/env bash
    BIN_NAME=$(basename "$0")
    HAS_DB_PATH=0
    for arg in "$@"; do
      if [ "$arg" = "--database-path" ]; then
        HAS_DB_PATH=1
        break
      fi
      case "$arg" in
        --database-path=*)
          HAS_DB_PATH=1
          break
          ;;
      esac
    done

    if [ "$HAS_DB_PATH" -eq 0 ]; then
      DB_PATH="''${XDG_DATA_HOME:-$HOME/.local/share}/claudecodeui/auth.db"
      mkdir -p "$(dirname "$DB_PATH")"
      exec "$(dirname "$0")/$BIN_NAME.original" --database-path "$DB_PATH" "$@"
    else
      exec "$(dirname "$0")/$BIN_NAME.original" "$@"
    fi
    WRAPPEREOF
            chmod +x "$out/bin/$bin"
          fi
        done
  '';
})
