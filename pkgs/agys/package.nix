{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  nix-update-script,
}:

buildGoModule rec {
  pname = "agys";
  version = "0.2.20";

  src = fetchFromGitHub {
    owner = "quaywin";
    repo = "agys";
    rev = "v${version}";
    hash = "sha256-7T4Z0rHkflRZ+n1sQbQEatW/Cukaon0PKic0DkBah1s=";
  };

  vendorHash = "sha256-w1m+4Axgu0siZbNJw0kOJAd+oVvr6YafasKtTuuOpPY=";

  subPackages = [ "." ];

  env.CGO_ENABLED = 0;

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/quaywin/agys/pkg/version.Version=${version}"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd agys \
      --bash <($out/bin/agys completion bash) \
      --zsh <($out/bin/agys completion zsh) \
      --fish <($out/bin/agys completion fish)

    install -Dm644 herdr-plugin.toml $out/share/herdr/plugins/quaywin.agys/herdr-plugin.toml
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/quaywin/agys"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Antigravity Ecosystem Switcher - Zero-collision multi-account orchestration for Antigravity & Herdr";
    homepage = "https://github.com/quaywin/agys";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "agys";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
