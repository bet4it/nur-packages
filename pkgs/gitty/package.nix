{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  oniguruma,
  darwin,
  nix-update-script,
}:

rustPlatform.buildRustPackage rec {
  pname = "gitty";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "VedangP57";
    repo = "gitty";
    tag = "v${version}";
    hash = "sha256-Ef+b29R+OZoGcFntKj6Mp9SkatOdbn99IWkmAFiEm8M=";
  };

  cargoHash = "sha256-Rj0HhqV90Go/EzkyXjU2UWUDjNE3nDvdZlaMWZ0Try0=";

  cargoBuildFlags = [
    "-p"
    "gitty-cli"
  ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    oniguruma
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk.frameworks.CoreServices
  ];

  env = {
    RUSTONIG_SYSTEM_LIBONIG = "1";
  };

  doCheck = false;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Fast terminal git client with the GitHub Desktop experience";
    homepage = "https://gitty.runs-on.dev";
    changelog = "https://github.com/VedangP57/gitty/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "gitty";
    platforms = lib.platforms.unix;
  };
}
