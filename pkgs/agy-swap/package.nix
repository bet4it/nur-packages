{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  makeWrapper,
  libsecret,
  nix-update-script,
}:

buildGoModule rec {
  pname = "agy-swap";
  version = "2.11.1";

  src = fetchFromGitHub {
    owner = "aklkbqx";
    repo = "agy-swap";
    rev = "v${version}";
    hash = "sha256-O7ORwZ7X3x1U3pHWKJFC5vjHvUAxcPIcQhTAM5ehm+A=";
  };

  vendorHash = "sha256-vKms/NRoVn39Q1nNFbOiaEgfgq3FhFaIBQvpW4kpDeQ=";

  subPackages = [ "cmd/agy-swap" ];

  env.CGO_ENABLED = 0;

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.buildID=nixpkgs"
  ];

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  postInstall = ''
    installShellCompletion --cmd agy-swap \
      --bash <($out/bin/agy-swap completion bash) \
      --zsh <($out/bin/agy-swap completion zsh) \
      --fish <($out/bin/agy-swap completion fish)
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/agy-swap \
      --prefix PATH : ${lib.makeBinPath [ libsecret ]}
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/aklkbqx/agy-swap"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "High-Performance Account Switcher & Quota Monitor for Google Antigravity (agy)";
    homepage = "https://github.com/aklkbqx/agy-swap";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "agy-swap";
    platforms = lib.platforms.linux ++ lib.platforms.darwin ++ lib.platforms.windows;
  };
}
