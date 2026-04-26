# nur-packages

Custom packages extracted from `nixos-config/pkgs`, maintained as a standalone flake/NUR-style repository.

## Usage

Use the binary cache:

```bash
cachix use bet4it
```

Or add it manually to your Nix configuration:

```nix
{
  nix.settings.substituters = [
    "https://bet4it.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "bet4it.cachix.org-1:/a9IrzSgxueTzTTPdgjTvBsOJRxpck0sV/lEcoA/aCo="
  ];
}
```

Run a package directly from the remote repository:

```bash
nix run github:bet4it/nur-packages#app-manager
nix run github:bet4it/nur-packages#termix
```

Run a package from a local checkout:

```bash
nix run .#app-manager
nix run .#termix
```

Inspect exported packages:

```bash
nix flake show
```

Use from another flake:

```nix
{
  inputs.bet4it-packages.url = "github:bet4it/nur-packages";
}
```

Install a package in NixOS:

```nix
{ inputs, pkgs, ... }:

{
  environment.systemPackages = [
    inputs.bet4it-packages.packages.${pkgs.system}.app-manager
    inputs.bet4it-packages.packages.${pkgs.system}.termix
  ];
}
```

Install a package with Home Manager:

```nix
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.bet4it-packages.packages.${pkgs.system}.app-manager
  ];
}
```

Import this repository without flakes:

```nix
let
  pkgs = import <nixpkgs> { };
  bet4it-packages = import (builtins.fetchTarball {
    url = "https://github.com/bet4it/nur-packages/archive/main.tar.gz";
  }) { inherit pkgs; };
in
{
  environment.systemPackages = [
    bet4it-packages.app-manager
  ];
}
```

## CI

GitHub Actions is configured in [.github/workflows/build.yml](./.github/workflows/build.yml).

The workflow evaluates the repository with NUR's restricted-eval check, builds
the package set from [ci.nix](./ci.nix), uploads cacheable outputs to Cachix,
and triggers a NUR index update for the `bet4it` repository.

Before enabling cache uploads, create the `bet4it` cache on Cachix and add one
of these GitHub repository secrets:

- `CACHIX_AUTH_TOKEN`
- `CACHIX_SIGNING_KEY`

The workflow evaluates and builds against `nixos-unstable`, matching the NUR
expectation that repositories keep working with unstable nixpkgs.
