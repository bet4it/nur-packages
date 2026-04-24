# nur-packages

Custom packages extracted from `nixos-config/pkgs`, maintained as a standalone flake/NUR-style repository.

## Usage

Run a package directly:

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
inputs.my-packages.url = "github:<your-user>/nur-packages";
```

```nix
inputs.my-packages.packages.${pkgs.system}.app-manager
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
