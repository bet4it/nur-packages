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
  version = "0.1.66";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionCore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-qIZL8Z6SufhzqE1AEGpL7BGYJ5wszK9kyIcTePWMlds=";
  };

  cargoHash = "sha256-n8+PFFutFCK3bbFayalQ3bm9vpt8WkEedx6Ae1tvpjk=";

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
