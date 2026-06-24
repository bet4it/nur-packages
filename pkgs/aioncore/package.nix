{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "aioncore";
  version = "0.1.36";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionCore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-0VCcfhpqoK7dDE88V+6Ke/yKqC0dS3jlHsqlKrXtC/Q=";
  };

  cargoHash = "sha256-IkaMqFLoikL23RErGED9fbNm7CrwHr/dYldne+j28yQ=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  buildAndTestSubdir = "crates/aionui-app";

  env = {
    OPENSSL_NO_VENDOR = true;
  };

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url=https://github.com/iOfficeAI/AionCore"
      "--use-github-releases"
    ];
  };

  meta = {
    description = "Backend runtime for AionUi";
    homepage = "https://github.com/iOfficeAI/AionCore";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "aioncore";
    platforms = lib.platforms.linux;
  };
})
