{ pkgs }:
{
  app-manager = pkgs.callPackage ./app-manager/package.nix { };
  athas = pkgs.callPackage ./athas/package.nix { };
  cc-switch = pkgs.callPackage ./cc-switch/package.nix { };
  ccg-gateway = pkgs.callPackage ./ccg-gateway/package.nix { };
  claude-code-history-viewer = pkgs.callPackage ./claude-code-history-viewer/package.nix { };
  claudecodeui = pkgs.callPackage ./claudecodeui/package.nix { };
  codexia = pkgs.callPackage ./codexia/package.nix { };
  desktop-cc-gui = pkgs.callPackage ./desktop-cc-gui/package.nix { };
  electerm = pkgs.callPackage ./electerm/package.nix { };
  herdr = pkgs.callPackage ./herdr/package.nix { };
  jean = pkgs.callPackage ./jean/package.nix { };
  metapi = pkgs.callPackage ./metapi/package.nix { };
  milkup = pkgs.callPackage ./milkup/package.nix { };
  neko-master = pkgs.callPackage ./neko-master/package.nix { };
  nexterm = pkgs.callPackage ./nexterm/package.nix { };
  qbit = pkgs.callPackage ./qbit/package.nix { };
  shell360 = pkgs.callPackage ./shell360/package.nix { };
  spacecake = pkgs.callPackage ./spacecake/package.nix { };
  termix = pkgs.callPackage ./termix/package.nix { };
  tokenicode = pkgs.callPackage ./tokenicode/package.nix { };
}
