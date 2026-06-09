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
  version = "0.1.24";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionCore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-FGYw/T8V0TWmlrCgdAEUg5ZAPhYMlBRY73/sMUYZY/o=";
  };

  cargoHash = "sha256-+ne5ySYeOzFBt2Qkn/H8tW73CwkW11sTHfzkr/EsZZg=";

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
