{
  coreutils,
  flutter344,
  nix,
  nix-update,
  writeShellApplication,
  yq-go,
}:

writeShellApplication {
  name = "update-kelivo";

  runtimeInputs = [
    coreutils
    flutter344
    nix
    nix-update
    yq-go
  ];

  text = ''
    pname="''${UPDATE_NIX_PNAME:-kelivo}"
    repo_dir="$(pwd)"

    nix-update --flake "$pname" --use-github-releases

    source="$(nix build --no-link --print-out-paths ".#''${pname}.src")"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    cp -R "$source" "$tmp_dir/source"
    chmod -R u+w "$tmp_dir/source"

    export HOME="$tmp_dir/home"
    mkdir -p "$HOME"

    cd "$tmp_dir/source"
    flutter pub get
    yq eval --output-format=json --prettyPrint \
      pubspec.lock > "$repo_dir/pkgs/kelivo/pubspec.lock.json"
  '';
}
