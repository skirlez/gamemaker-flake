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
      tmp=$(mktemp -d)
      7zz -y x $src bin/igor/linux/x64 -o$tmp -p${runtimeLockfile.${runtimeVersion}.tools.password}
      mv $tmp/bin/igor/linux/x64/* $out/bin
    '';
    installPhase = ''
      chmod +x $out/bin/Igor
    '';
    meta = {
      mainProgram = "Igor";
    };
  };
in
# the above works except it calls /bin/bash (lol), so we need to use buildFHSEnv.
# i wonder if there's any point using autoPatchelfHook in this case...
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
