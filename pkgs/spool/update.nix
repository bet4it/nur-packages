{
  coreutils,
  gnused,
  jq,
  nix,
  nix-update,
  pnpm_10,
  writeShellApplication,
}:

writeShellApplication {
  name = "update-spool";

  runtimeInputs = [
    coreutils
    gnused
    jq
    nix
    nix-update
    pnpm_10
  ];

  text = ''
    pname="''${UPDATE_NIX_PNAME:-spool}"
    repo_dir="$(pwd)"
    package_dir="$repo_dir/pkgs/spool"

    nix-update --flake "$pname" --use-github-releases --src-only

    source="$(nix build --no-link --print-out-paths ".#''${pname}.src")"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    cp -R "$source" "$tmp_dir/source"
    chmod -R u+w "$tmp_dir/source"

    cp "$tmp_dir/source/packages/app/package.json" "$package_dir/packages/app/package.json"
    cp "$tmp_dir/source/packages/core/package.json" "$package_dir/packages/core/package.json"

    update_json() {
      local file="$1"
      local filter="$2"
      local tmp_json
      tmp_json="$(mktemp)"
      jq "$filter" "$file" > "$tmp_json"
      mv "$tmp_json" "$file"
    }

    update_json "$package_dir/packages/app/package.json" '
      .dependencies["better-sqlite3"] = "^12.9.0"
      | .devDependencies["electron-builder"] = "^26.8.2"
    '
    update_json "$package_dir/packages/core/package.json" '
      .dependencies["better-sqlite3"] = "^12.9.0"
    '

    cp "$package_dir/packages/app/package.json" "$tmp_dir/source/packages/app/package.json"
    cp "$package_dir/packages/core/package.json" "$tmp_dir/source/packages/core/package.json"

    export HOME="$tmp_dir/home"
    export COREPACK_ENABLE_PROJECT_SPEC=0
    mkdir -p "$HOME"

    cd "$tmp_dir/source"
    pnpm install --lockfile-only --ignore-scripts
    cp pnpm-lock.yaml "$package_dir/pnpm-lock.yaml"

    cd "$repo_dir"
    update_pnpm_hash() {
      local hash="$1"
      sed -i -E \
        '/pnpmDeps = fetchPnpmDeps \{/,/^  \};/ s|hash = "sha256-[^"]+";|hash = "'"$hash"'";|' \
        "$package_dir/package.nix"
    }

    update_pnpm_hash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    set +e
    pnpm_hash_output="$(nix build --no-link ".#''${pname}.pnpmDeps" 2>&1)"
    pnpm_hash_status="$?"
    set -e

    pnpm_hash="$(printf '%s\n' "$pnpm_hash_output" \
      | sed -n 's/.*got:[[:space:]]*//p' \
      | tail -n 1)"
    if [ -z "$pnpm_hash" ]; then
      echo "failed to discover pnpmDeps hash" >&2
      printf '%s\n' "$pnpm_hash_output" >&2
      exit "$pnpm_hash_status"
    fi
    if [ "$pnpm_hash_status" -eq 0 ]; then
      echo "expected pnpmDeps fake hash build to fail" >&2
      exit 1
    fi
    update_pnpm_hash "$pnpm_hash"
  '';
}
