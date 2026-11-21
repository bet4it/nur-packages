{
  config,
  lib,
  pkgs,
  ...
}:
# Declarative installation of the Xrose privilege helper (TUN / system DNS /
# transparent proxy). The helper is the same component the GUI would install
# through pkexec as `/etc/systemd/system/xrose-helper.service`; on NixOS that
# imperative flow cannot work (/etc/systemd/system is a read-only symlink into
# the store), so the unit is declared here instead. The GUI detects it because
# it checks for that exact unit path, and talks to the running helper over its
# local socket — no elevation prompt involved.
#
# This mirrors how NixOS packages the same problem in clash-verge
# (`programs.clash-verge.serviceMode`) and mihomo/sing-box/tailscale
# (`services.*`): root systemd services declared in configuration.nix.
let
  cfg = config.services.xrose-helper;

  # The helper's IPC layer accepts exactly one non-root UID (`--allow-uid`,
  # a single OnceLock<u32> upstream), so the module requires one.
  allowedUids =
    lib.optional (cfg.uid != null) cfg.uid
    ++ lib.optional (cfg.user != null) config.users.users.${cfg.user}.uid;

  execUid =
    if lib.length allowedUids == 1 then
      lib.head allowedUids
    else
      throw "services.xrose-helper: set exactly one of `uid` or `user` (the helper accepts a single desktop user, and the named user needs a static UID)";
in
{
  options.services.xrose-helper = {
    enable = lib.mkEnableOption ''
      the Xrose privilege helper. Enables TUN mode, system DNS takeover and
      transparent proxying in the xrose GUI without running it as root.
      Implies installing {file}`xrose-app` or adding its package to the system.
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xrose or (throw "services.xrose-helper requires pkgs.xrose (from nur-packages)");
      defaultText = lib.literalExpression "pkgs.xrose";
      description = "The xrose package providing the helper entry point.";
    };

    uid = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.u32;
      default = null;
      example = 1000;
      description = ''
        UID of the desktop user allowed to talk to the helper. Exactly one of
        {option}`uid` or {option}`user` must be set.
      '';
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        Name of the desktop user allowed to talk to the helper; resolved
        through {option}`config.users.users`. Exactly one of {option}`uid` or
        {option}`user` must be set.
      '';
    };

    nftables = lib.mkEnableOption ''
      adding nftables to the helper's PATH, required for transparent proxy
      (tproxy) rules. Only the ruleset application is covered here; enable
      {option}`networking.nftables` for the kernel-side support too.
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length allowedUids == 1;
        message = ''
          services.xrose-helper requires exactly one of {option}`uid` or
          {option}`user` (the helper accepts a single desktop user), and the
          named user must have a static UID (set
          {option}`users.users.<name>.uid`).
        '';
      }
    ];

    systemd.services.xrose-helper = {
      description = "Xrose privilege helper (TUN / DNS / transparent proxy)";
      documentation = [ "https://github.com/zuoxinyu/xrose" ];
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # The helper shells out for: resolvectl (systemd, in the default
      # manager PATH), ip, modprobe and nft. The proxy cores themselves are
      # reached through the wrapper's PATH (xray / sing-box from the
      # package).
      path = [ pkgs.iproute2 pkgs.kmod ] ++ lib.optional cfg.nftables pkgs.nftables;

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/xrose-cli"
            "--helper"
            "--allow-uid"
            (toString execUid)
          ]
        );
        Restart = "on-failure";
        RestartSec = 2;

        # TUN device creation, raw sockets, low ports for the tproxy listener.
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
          "CAP_NET_BIND_SERVICE"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
          "CAP_NET_BIND_SERVICE"
        ];

        # No PrivateTmp: the helper publishes its control socket at
        # /tmp/io.xrose.helper.v1 and the GUI connects to it from outside the
        # service namespace.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_PACKET"
        ];
      };
    };
  };
}
