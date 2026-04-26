#!/usr/bin/env bash
set -euo pipefail

if ! command -v crane >/dev/null || ! command -v jq >/dev/null || ! command -v nix-update >/dev/null; then
  exec nix shell \
    nixpkgs#crane \
    nixpkgs#jq \
    nixpkgs#nix-update \
    -c "$0" "$@"
fi

package_file="pkgs/neko-master/package.nix"
image="ghcr.io/foru17/neko-master"

current_version="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$package_file" | head -n1)"
latest_version="$(crane ls "$image" | sed -nE '/^[0-9]+(\.[0-9]+){2}$/p' | sort -V | tail -n1)"

if [ -z "$latest_version" ]; then
  echo "No semver tags found for $image"
  exit 1
fi

if [ "$(printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V | tail -n1)" != "$latest_version" ]; then
  echo "Latest container tag $latest_version is older than packaged version $current_version; skipping"
  exit 0
fi

if [ "$latest_version" = "$current_version" ]; then
  echo "neko-master is already at latest container tag $latest_version"
  exit 0
fi

image_config="$(crane config "$image:$latest_version")"
revision="$(jq -r '.config.Labels."org.opencontainers.image.revision" // empty' <<< "$image_config")"
image_version="$(jq -r '.config.Labels."org.opencontainers.image.version" // empty' <<< "$image_config")"

if [ -z "$revision" ]; then
  echo "Image $image:$latest_version does not expose org.opencontainers.image.revision"
  exit 1
fi

if [ -n "$image_version" ] && [ "$image_version" != "$latest_version" ]; then
  echo "Image label version $image_version does not match tag $latest_version"
  exit 1
fi

echo "Updating neko-master $current_version -> $latest_version ($revision)"

sed -i -E '0,/rev = "[^"]+";/s//rev = "'"$revision"'";/' "$package_file"

nix-update --flake neko-master --version="$latest_version"
