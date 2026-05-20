{ pkgs }:
{
  app-manager = pkgs.callPackage ./app-manager/package.nix { };
  athas = pkgs.callPackage ./athas/package.nix { };
  cc-switch = pkgs.callPackage ./cc-switch/package.nix { };
  ccg-gateway = pkgs.callPackage ./ccg-gateway/package.nix { };
  claude-code-history-viewer = pkgs.callPackage ./claude-code-history-viewer/package.nix { };
  desktop-cc-gui = pkgs.callPackage ./desktop-cc-gui/package.nix { };
  electerm = pkgs.callPackage ./electerm/package.nix { };
  jean = pkgs.callPackage ./jean/package.nix { };
  kelivo = pkgs.callPackage ./kelivo/package.nix { };
  milkup = pkgs.callPackage ./milkup/package.nix { };
  netcatty = pkgs.callPackage ./netcatty/package.nix { };
  nexterm = pkgs.callPackage ./nexterm/package.nix { };
  oxideterm = pkgs.callPackage ./oxideterm/package.nix { };
  paseo-desktop = pkgs.callPackage ./paseo-desktop/package.nix { };
  qbit = pkgs.callPackage ./qbit/package.nix { };
  shell360 = pkgs.callPackage ./shell360/package.nix { };
  spacecake = pkgs.callPackage ./spacecake/package.nix { };
  spool = pkgs.callPackage ./spool/package.nix { };
  superset = pkgs.callPackage ./superset/package.nix { };
  termix = pkgs.callPackage ./termix/package.nix { };
  tokenicode = pkgs.callPackage ./tokenicode/package.nix { };
  vibe99 = pkgs.callPackage ./vibe99/package.nix { };
  vibemux = pkgs.callPackage ./vibemux/package.nix { };
}
