{ pkgs }:
rec {
  app-manager = pkgs.callPackage ./app-manager/package.nix { };
  aioncore = pkgs.callPackage ./aioncore/package.nix { };
  athas = pkgs.callPackage ./athas/package.nix { };
  cc-switch = pkgs.callPackage ./cc-switch/package.nix { };
  cc-session = pkgs.callPackage ./cc-session/package.nix { };
  ccg-gateway = pkgs.callPackage ./ccg-gateway/package.nix { };
  claude-code-history-viewer = pkgs.callPackage ./claude-code-history-viewer/package.nix { };
  electerm = pkgs.callPackage ./electerm/package.nix { };
  jean = pkgs.callPackage ./jean/package.nix { };
  kelivo = pkgs.callPackage ./kelivo/package.nix { };
  milkup = pkgs.callPackage ./milkup/package.nix { };
  netcatty = pkgs.callPackage ./netcatty/package.nix { };
  oxideterm = pkgs.callPackage ./oxideterm/package.nix { };
  paseo-desktop = pkgs.callPackage ./paseo-desktop/package.nix { };
  shell360 = pkgs.callPackage ./shell360/package.nix { };
  spool = pkgs.callPackage ./spool/package.nix { };
  superset = pkgs.callPackage ./superset/package.nix { };
  tokenicode = pkgs.callPackage ./tokenicode/package.nix { };
  usbee = pkgs.callPackage ./usbee/package.nix { inherit usbeehive; };
  vibe99 = pkgs.callPackage ./vibe99/package.nix { };
  vibemux = pkgs.callPackage ./vibemux/package.nix { };
  vmark = pkgs.callPackage ./vmark/package.nix { };
  usbeehive = pkgs.callPackage ./usbeehive/package.nix { };
  fast-resume = pkgs.callPackage ./fast-resume/package.nix { };
}
