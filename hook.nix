{
  pkgs ? import <nixpkgs> { },
  artifactDir,
  htmlDir,
}:

let
  version = "0.1.2";

  src = pkgs.lib.fileset.toSource {
    root = ./.;
    fileset = pkgs.lib.fileset.unions [
      ./build.zig
      ./build.zig.zon
      ./src
      ./LICENSE
    ];
  };

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  appleSdk =
    if isDarwin then
      pkgs.apple-sdk
    else
      let
        sdk =
          (import <nixpkgs> {
            config = pkgs.config // {
              allowUnsupportedSystem = true;
            };
          }).apple-sdk.override
            { enableBootstrap = true; };
      in
      sdk.overrideAttrs (old: {
        postBuild = (old.postBuild or "") + ''
          for header in ${pkgs.lib.getDev pkgs.cups}/include/*; do
            ln -sf "$header" "usr/include/$(basename "$header")"
          done
        '';
      });

  sdkRoot = "${appleSdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";

  targets = {
    x86_64-linux-musl = "tpb-linux-x86_64";
    aarch64-linux-musl = "tpb-linux-aarch64";
    x86_64-macos = "tpb-macos-x86_64";
    aarch64-macos = "tpb-macos-aarch64";
  };

  binaries = pkgs.stdenv.mkDerivation {
    pname = "tpb-static-binaries";
    inherit version src;

    nativeBuildInputs = [ pkgs.zig_0_16 ];

    dontConfigure = true;
    doCheck = false;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
      ${pkgs.lib.concatMapStrings (target: ''
        zig build \
          -Dtarget=${target} \
          -Doptimize=ReleaseSafe \
          --prefix zig-out/${target} \
          ${pkgs.lib.optionalString (pkgs.lib.hasSuffix "-macos" target) ''--sysroot "${sdkRoot}"''}
      '') (builtins.attrNames targets)}
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      ${pkgs.lib.concatMapStrings (target: ''
        cp zig-out/${target}/bin/tpb $out/${targets.${target}}
      '') (builtins.attrNames targets)}
      runHook postInstall
    '';
  };
in
pkgs.writeShellScriptBin "deploy" ''
  set -euo pipefail

  mkdir -p ${pkgs.lib.escapeShellArg artifactDir}
  mkdir -p ${pkgs.lib.escapeShellArg htmlDir}

  ${pkgs.rsync}/bin/rsync -a --delete \
    ${binaries}/ \
    ${pkgs.lib.escapeShellArg (artifactDir + "/")}
''
