{
  description = "Custom Nix packages";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgs = system: import nixpkgs { inherit system; };
      mkApps =
        system:
        let
          packages = self.packages.${system};
        in
        nixpkgs.lib.mapAttrs
          (_: pkg: {
            type = "app";
            program = "${pkg}/bin/${pkg.meta.mainProgram}";
          })
          (
            nixpkgs.lib.filterAttrs (
              _: pkg: nixpkgs.lib.isDerivation pkg && (pkg.meta.mainProgram or null) != null
            ) packages
          );
    in
    {
      legacyPackages = forAllSystems (
        system:
        import ./default.nix {
          pkgs = mkPkgs system;
        }
      );
      packages = forAllSystems (
        system: nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system}
      );
      apps = forAllSystems mkApps;
      formatter = forAllSystems (system: (mkPkgs system).nixfmt-tree);
      nixosModules = import ./nixos-modules;
      # homeModules = import ./home-modules;
      # darwinModules = import ./darwin-modules;
      # flakeModules = import ./flake-modules;
    };
}
