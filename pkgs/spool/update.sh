#!/usr/bin/env bash
set -euo pipefail

if ! command -v npm >/dev/null || ! command -v nix >/dev/null; then
  exec nix shell nixpkgs#nodejs -c "$0" "$@"
fi

package="spool"
npm_package="@spool-lab/cli"
package_file="pkgs/$package/package.nix"
lockfile="pkgs/$package/package-lock.json"

current_version="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$package_file" | head -n1)"
requested_version="${1:-}"

if [ -n "$requested_version" ]; then
  latest_version="${requested_version#v}"
else
  latest_version="$(npm view "$npm_package" version)"
fi

if [ "$latest_version" = "$current_version" ]; then
  echo "$package is already at $latest_version"
  exit 0
fi

echo "Updating $package $current_version -> $latest_version"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Fetching $npm_package@$latest_version tarball"
tarball_url="$(npm view "$npm_package@$latest_version" dist.tarball)"
tarball_hash="$(nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 "$tarball_url" 2>/dev/null)")"

echo "Regenerating package-lock.json"
mkdir -p "$tmp_dir/pkg"
curl -fsSL "$tarball_url" | tar -xz -C "$tmp_dir/pkg" --strip-components=1
(
  cd "$tmp_dir/pkg"
  npm install --package-lock-only --ignore-scripts
)
cp "$tmp_dir/pkg/package-lock.json" "$lockfile"

sed -i -E "s/version = \"[^\"]+\";/version = \"$latest_version\";/" "$package_file"
sed -i -E "s#url = \"https://registry.npmjs.org/@spool-lab/cli/-/cli-[^\"]+\";#url = \"https://registry.npmjs.org/@spool-lab/cli/-/cli-\${version}.tgz\";#" "$package_file"
sed -i -E "/npmTarball = fetchurl \{/,/\};/ s|hash = \"sha256-[^\"]+\";|hash = \"$tarball_hash\";|" "$package_file"
sed -i -E "s/npmDepsHash = \"sha256-[^\"]+\";/npmDepsHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";/" "$package_file"

set +e
build_output="$(nix build --no-link ".#$package" 2>&1)"
build_status=$?
set -e

npm_deps_hash="$(printf '%s\n' "$build_output" | sed -n 's/.*got:[[:space:]]*//p' | tail -n 1)"
if [ -z "$npm_deps_hash" ]; then
  echo "Failed to discover npmDepsHash" >&2
  printf '%s\n' "$build_output" >&2
  exit "$build_status"
fi

sed -i -E "s/npmDepsHash = \"sha256-[^\"]+\";/npmDepsHash = \"$npm_deps_hash\";/" "$package_file"
