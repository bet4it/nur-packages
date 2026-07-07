#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null || ! command -v nix-update >/dev/null; then
  exec nix shell \
    nixpkgs#gh \
    nixpkgs#nix-update \
    -c "$0" "$@"
fi

package="nyaterm"
repo="nyakang/nyaterm"
package_file="pkgs/$package/package.nix"

current_version="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$package_file" | head -n1)"
requested_version="${1:-}"

if [ -n "$requested_version" ]; then
  latest_version="${requested_version#v}"
else
  latest_version="$(gh release view --repo "$repo" --json tagName --jq '.tagName | sub("^v"; "")')"
fi

if [ -z "$latest_version" ]; then
  echo "Failed to determine latest version for $repo"
  exit 1
fi

if [ "$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V | tail -n1)" != "$latest_version" ]; then
  echo "Latest version $latest_version is older than packaged version $current_version; skipping"
  exit 0
fi

if [ "$latest_version" = "$current_version" ]; then
  echo "$package is already at $latest_version"
  exit 0
fi

probe_hash() {
  local expr="$1"
  local output
  local status

  set +e
  output="$(
    nix build --impure --no-link --print-out-paths \
      --expr "$expr" \
      --extra-experimental-features "flakes nix-command" \
      2>&1
  )"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "Expected hash probe to fail with a mismatch, but it succeeded" >&2
    exit 1
  fi

  local hash
  hash="$(sed -nE 's/^[[:space:]]*got:[[:space:]]*(sha256-[A-Za-z0-9+/=]+)$/\1/p' <<< "$output" | tail -n1)"

  if [ -z "$hash" ]; then
    printf '%s\n' "$output" >&2
    echo "Failed to extract hash from build output" >&2
    exit 1
  fi

  printf '%s\n' "$hash"
}

echo "Updating $package $current_version -> $latest_version"

nix-update -f default.nix "$package" --version "$latest_version" --src-only

main_hash="$(probe_hash "(let pkg = (import ./default.nix { }).$package; src = pkg.cargoDeps.vendorStaging; in (src.overrideAttrs (_: { outputHash = \"\"; outputHashAlgo = \"sha256\"; })))")"
pnpm_hash="$(probe_hash "(let pkg = (import ./default.nix { }).$package; src = pkg.pnpmDeps; in (src.overrideAttrs (_: { outputHash = \"\"; outputHashAlgo = \"sha256\"; })))")"

sed -i -E 's|cargoHash = [^;]+;|cargoHash = "'"$main_hash"'";|' "$package_file"
sed -i -E '/pnpmDeps = fetchPnpmDeps \{/,/};/ s|hash = [^;]+;|hash = "'"$pnpm_hash"'";|' "$package_file"
