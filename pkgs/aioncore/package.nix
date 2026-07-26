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
  version = "0.1.52";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionCore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-LfbfE1A7yJSwbgTG6t8u/6OQV8p/JB0cYsp+gebj7zY=";
  };

  cargoHash = "sha256-OP8gNV4vcxlzeKEogt5POcEbMowDbiGQc5bpss/XnLg=";

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
