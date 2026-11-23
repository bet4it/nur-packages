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
  version = "0.0.91";

  src = fetchFromGitHub {
    owner = "pulkitxm";
    repo = "quinjet";
    tag = "v${version}";
    hash = "sha256-/zVz7qng3SP9IYES8AvMhpDNr6k+lNz86fkzYO6ujVg=";
  };

  cargoHash = "sha256-mAHFYwcdop2kKmKW0ycnRzYuXQpv5PQg+qW8OC1if+Q=";

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
