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

Before pushing, update:

- `nurRepo` if you want to trigger NUR index updates
- `cachixName` and repository secrets if you want Cachix uploads

The workflow currently evaluates and builds against `nixos-25.11`, which matches the migrated package set.
