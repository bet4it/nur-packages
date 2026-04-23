{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  nodejs,
  python3,
  makeWrapper,
  electron_40,
  writableTmpDirAsHomeHook,
  wrapGAppsHook3,
  asar,
  patchelf,
}:

let
  electron = electron_40;
  ortArch =
    if stdenv.hostPlatform.isx86_64 then
      "x64"
    else if stdenv.hostPlatform.isAarch64 then
      "arm64"
    else
      throw "Unsupported platform for superset onnxruntime-node: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "superset";
  version = "1.5.7";

  src = fetchFromGitHub {
    owner = "superset-sh";
    repo = "superset";
    tag = "desktop-v${finalAttrs.version}";
    hash = "sha256-6E/BSs3Eg43OFcH9JZNjM3DUBARGPhEZdGTlW1BYhbc=";
  };

  node_modules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      nodejs
      python3
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      export CI=1
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      export npm_config_nodedir=${electron.headers}

      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --no-cache \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;

      # Bun can emit mode bits that differ across hosts; normalize them so the
      # fixed-output hash only reflects file contents and dependency layout.
      find $out -type d -print0 | xargs -0 -r chmod 555
      find $out -type f -print0 | xargs -0 -r chmod 444
      find $out -path "*/node_modules/.bin/*" -type f -print0 | xargs -0 -r chmod 555

      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-cTspTkiZn6vOEjWzKEZ5mKA0+uDTyyGIYgZe5CpDKNA=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    nodejs
    python3
    makeWrapper
    writableTmpDirAsHomeHook
    wrapGAppsHook3
    asar
    patchelf
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # Increase Node.js heap size for building large frontend apps
    NODE_OPTIONS = "--max-old-space-size=8192";
    # Skip environment validation during build (OAuth credentials not needed for local use)
    SKIP_ENV_VALIDATION = "true";
    # Provide placeholder OAuth client IDs (OAuth login won't work without real values)
    GOOGLE_CLIENT_ID = "placeholder";
    GH_CLIENT_ID = "placeholder";
  };

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .

    # Make node_modules writable and patch shebangs
    find . -type d -name node_modules -exec chmod -R u+rw {} \;
    find . -path "*/node_modules/.bin" -type d -exec chmod -R u+x {} \;
    patchShebangs .

    export HOME=$TMPDIR
    export npm_config_nodedir=${electron.headers}

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # Build the desktop app
    cd apps/desktop

    # Add local node_modules/.bin to PATH
    export PATH="$PWD/node_modules/.bin:$PATH"

    # Generate icons
    bun run generate:icons

    # Run electron-vite build first so validate-native-runtime can check the output
    electron-vite build

    # Prepare native modules using project's own scripts.
    # This handles the complex bun + @ast-grep/napi symlink layout.
    bun run copy:native-modules
    # validate:native-runtime checks if the modules can be loaded.
    export LD_LIBRARY_PATH="${lib.makeLibraryPath finalAttrs.buildInputs}:$LD_LIBRARY_PATH"
    bun run validate:native-runtime

    # Run electron-builder with upstream config
    electron-builder \
      --linux \
      --dir \
      --config electron-builder.ts \
      -c.electronDist=${electron.dist} \
      -c.electronVersion=${electron.version}

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        mkdir -p "$out/opt/superset"
        mkdir -p "$out/libexec/superset-onnxruntime"
        cp -r release/linux-unpacked/resources "$out/opt/superset/"
        # Extract asar, inject migrations and browser-extension into it, then repack.
        # The app code resolves these paths relative to __dirname inside the asar
        # (e.g. app.asar/dist/resources/migrations), so extraResources alone
        # (which places files outside the asar) is not sufficient.
        tmp=$(mktemp -d)
        asar extract "$out/opt/superset/resources/app.asar" "$tmp"

        if [ -f "$tmp/node_modules/onnxruntime-node/dist/binding.js" ]; then
          substituteInPlace "$tmp/node_modules/onnxruntime-node/dist/binding.js" \
            --replace-fail 'require(`../bin/napi-v3/''${process.platform}/''${process.arch}/onnxruntime_binding.node`)' "require(\"$out/libexec/superset-onnxruntime/onnxruntime_binding.node\")"
        fi

        mkdir -p "$tmp/dist/resources"
        cp -r "$out/opt/superset/resources/resources/migrations" "$tmp/dist/resources/"

        if [ -d "$out/opt/superset/resources/resources/browser-extension" ]; then
          mkdir -p "$tmp/dist/src/resources"
          cp -r "$out/opt/superset/resources/resources/browser-extension" "$tmp/dist/src/resources/"
        fi

        rm "$out/opt/superset/resources/app.asar"
        asar pack "$tmp" "$out/opt/superset/resources/app.asar"
        rm -rf "$tmp"

        # Keep the vendored ONNX runtime discoverable at runtime and add
        # libstdc++ for the prebuilt native bindings shipped by upstream.
        ort_dir="$out/opt/superset/resources/app.asar.unpacked/node_modules/onnxruntime-node/bin/napi-v3/linux/${ortArch}"
        if [ -n "$ort_dir" ] && [ -d "$ort_dir" ]; then
          ort_rpath="$out/libexec/superset-onnxruntime:${
            lib.makeLibraryPath [ (lib.getLib stdenv.cc.cc) ]
          }"

          cp "$ort_dir/onnxruntime_binding.node" "$out/libexec/superset-onnxruntime/onnxruntime_binding.node"

          for runtime_lib in \
            "$ort_dir/libonnxruntime.so.1" \
            "$ort_dir/libonnxruntime.so.1.21.0" \
            "$ort_dir/libonnxruntime_providers_shared.so"
          do
            if [ -f "$runtime_lib" ]; then
              ln -s "$runtime_lib" "$out/libexec/superset-onnxruntime/$(basename "$runtime_lib")"
            fi
          done

          for native in \
            "$out/libexec/superset-onnxruntime/onnxruntime_binding.node" \
            "$ort_dir/libonnxruntime.so.1" \
            "$ort_dir/libonnxruntime_providers_shared.so"
          do
            if [ -f "$native" ]; then
              chmod u+w "$native"
              patchelf \
                --set-rpath "$ort_rpath" \
                "$native"
            fi
          done
        fi

        # Create wrapper using system electron
        makeWrapper "${electron}/bin/electron" "$out/bin/superset" \
          "''${gappsWrapperArgs[@]}" \
          --set ELECTRON_IS_DEV 0 \
          --prefix LD_LIBRARY_PATH : "$out/libexec/superset-onnxruntime:${
            lib.makeLibraryPath [ (lib.getLib stdenv.cc.cc) ]
          }" \
          --add-flags "$out/opt/superset/resources/app.asar" \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

        # Install icons
        install -Dm644 src/resources/build/icons/icon.png "$out/share/icons/hicolor/512x512/apps/superset.png"

        # Create desktop file with absolute paths for protocol handler support
        mkdir -p "$out/share/applications"
        cat > "$out/share/applications/superset.desktop" << EOF
    [Desktop Entry]
    Type=Application
    Name=Superset
    Comment=${finalAttrs.meta.description}
    Exec=$out/bin/superset %U
    Icon=$out/share/icons/hicolor/512x512/apps/superset.png
    Categories=Development;Utility;
    MimeType=x-scheme-handler/superset;
    StartupWMClass=Superset
    EOF

        runHook postInstall
  '';

  dontWrapGApps = true;

  meta = {
    description = "The last developer tool you'll ever need";
    homepage = "https://superset.sh";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "superset";
  };
})
