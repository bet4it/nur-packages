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
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "aklkbqx";
    repo = "agy-swap";
    rev = "v${version}";
    hash = "sha256-skzdMzvCVm4idx/mvsIpNmVlYLTbZrIT9rLXyhO28zo=";
  };

  vendorHash = "sha256-8DVgOm8ly/t6nLCRJE2QZ4JpxePPAJEr//r5rEWyYao=";

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
