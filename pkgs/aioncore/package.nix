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
  version = "0.1.20";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "AionCore";
    rev = "v${finalAttrs.version}";
    hash = "sha256-79ZhjdZeanY4A1TZOBSfMY2SbZ9oTjtETel7Tav5AL8=";
  };

  cargoHash = "sha256-F2Guv3zbWBwWYiAdxqbZYcRSXU7/eFngYso+l0gdQCk=";

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
