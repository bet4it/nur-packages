{
  description = "My personal NUR repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      legacyPackages = forAllSystems (system: import ./default.nix {
        pkgs = pkgsFor system;
      });
      packages = forAllSystems (system: lib.filterAttrs (_: v: lib.isDerivation v) self.legacyPackages.${system});
      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          ci = import ./ci.nix { inherit pkgs; };
        in
        {
          cacheOutputs = pkgs.linkFarmFromDrvs "nur-packages-cache-outputs" ci.cacheOutputs;
          buildOutputs = pkgs.linkFarmFromDrvs "nur-packages-build-outputs" ci.buildOutputs;
        });
      nixosModules = import ./nixos-modules;
      # homeModules = import ./home-modules;
      # darwinModules = import ./darwin-modules;
      # flakeModules = import ./flake-modules;
    };
}
