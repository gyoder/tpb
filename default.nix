{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenv.mkDerivation {
  pname = "tpb";
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

  nativeBuildInputs = [
    pkgs.zig_0_16
  ]
  ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.makeWrapper;

  zigBuildFlags = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    "--sysroot"
    "${pkgs.apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  ];

  postFixup = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/tpb" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.wl-clipboard
          pkgs.xclip
        ]
      }
  '';

  doCheck = false;

  meta = {
    description = "Tee your Paste Board";
    homepage = "https://git.gae.moe/grace/tpb";
    license = pkgs.lib.licenses.mit;
    mainProgram = "tpb";
    platforms = pkgs.lib.platforms.unix;
  };
}
