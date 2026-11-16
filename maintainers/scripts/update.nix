{
  package ? null,
  ...
}:

if package == null then
  throw "Please provide --argstr package <name>"
else
  let
    nixpkgs = import <nixpkgs> {
      config = {
        checkMeta = false;
        allowInsecurePredicate = _: true;
        allowUnfree = true;
      };
    };
    nurPkgs = import ./../../default.nix { pkgs = nixpkgs; };
    lib = nixpkgs.lib;
    pkg =
      lib.attrByPath (lib.splitString "." package) null nurPkgs;
    _ =
      if pkg == null then
        throw "Package '${package}' not found in repository"
      else
        null;
    updateScript =
      pkg.updateScript or (throw "Package '${package}' does not have an updateScript");
    rawScript = updateScript.command or updateScript;
    scriptList = if builtins.isList rawScript then rawScript else [ rawScript ];
    script = lib.escapeShellArgs (map toString scriptList);
    attrPath = updateScript.attrPath or package;
  in
  nixpkgs.mkShell {
    shellHook = ''
      unset shellHook
      export UPDATE_NIX_NAME="${pkg.name}"
      export UPDATE_NIX_PNAME="${lib.getName pkg}"
      export UPDATE_NIX_OLD_VERSION="${lib.getVersion pkg}"
      export UPDATE_NIX_ATTR_PATH="${attrPath}"
      exec ${script}
    '';
  }
