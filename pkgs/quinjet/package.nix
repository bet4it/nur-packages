{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  darwin,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "quinjet";
  version = "0.0.90";

  src = fetchFromGitHub {
    owner = "pulkitxm";
    repo = "quinjet";
    tag = "v${version}";
    hash = "sha256-Ep1JOflpqnhoH3MXCK8MO8tTa1ArFZ437kzOG9hhId8=";
  };

  cargoHash = "sha256-Y77ZeKeo3uxWUZ+qJYkHUwm+iN/vKfXgNYRu7tNhg6U=";

  nativeBuildInputs = [
    installShellFiles
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk.frameworks.CoreServices
  ];

  doCheck = false;

  postInstall = ''
    ln -s quinjet $out/bin/q
  '' + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    $out/bin/quinjet man > quinjet.1
    installManPage quinjet.1

    installShellCompletion --cmd quinjet \
      --bash <($out/bin/quinjet completions bash) \
      --zsh <($out/bin/quinjet completions zsh) \
      --fish <($out/bin/quinjet completions fish)
    installShellCompletion --cmd q \
      --bash <($out/bin/quinjet completions bash) \
      --zsh <($out/bin/quinjet completions zsh) \
      --fish <($out/bin/quinjet completions fish)
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Fast, live, keyboard-first Git source-control interface for the terminal";
    homepage = "https://github.com/pulkitxm/quinjet";
    changelog = "https://github.com/pulkitxm/quinjet/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "quinjet";
    platforms = lib.platforms.unix;
  };
}
