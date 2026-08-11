{
  pkgs,
  toolsZip,
  runtimeVersion,
  runtimeLockfile,
}:
let
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;
  igor = stdenv.mkDerivation {
    name = "Igor-${runtimeVersion}";
    src = toolsZip;
    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      makeWrapper
      _7zz
    ];

    # errors if you do
    dontStrip = true;

    buildInputs = with pkgs; [
      gcc.cc.lib
      zlib
      # wanted by igor at least on 2022.6
      lttng-ust_2_12
    ];
    strictDeps = true;
    unpackPhase = ''
      mkdir -p $out/temp
      mkdir -p $out/bin
      7zz -y x $src bin/igor/linux/x64 -o$out/temp -p${runtimeLockfile.${runtimeVersion}.tools.password}
      cp -r $out/temp/bin/igor/linux/x64/* $out/bin
      rm -r $out/temp
    '';
    installPhase = ''
      chmod +x $out/bin/Igor
    '';
    meta = {
      mainProgram = "Igor";
    };
  };
in
# the above works but calls /bin/bash (lol)
# i also moved the equivalent setting of DOTNET_SYSTEM_GLOBALIZATION_INVARIANT from gmac
# to the profile here
pkgs.buildFHSEnv {
  name = "Igor";
  targetPkgs = pkgs: [
    igor
    pkgs.ffmpeg
    pkgs.bash
    pkgs.openssl
  ];
  profile = ''
    export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
  '';
  runScript = "Igor";
}
