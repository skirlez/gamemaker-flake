{
  pkgs,
  toolsZip,
  runtimeVersion,
  runtimeLockfile,
}:
let
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;
in
stdenv.mkDerivation {
  name = "GMAssetCompiler-${runtimeVersion}";
  src = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.tools.url;
    sha256 = runtimeLockfile.${runtimeVersion}.tools.sha256;
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
    p7zip
  ];

  # errors if you do
  dontStrip = true;

  buildInputs = with pkgs; [
    gcc.cc.lib
    zlib
    fontconfig
    lttng-ust_2_12
  ];
  strictDeps = true;
  unpackPhase = ''
    mkdir -p $out/temp
    mkdir -p $out/bin
    7z -y x $src bin/assetcompiler/linux/x64 -o$out/temp -p${
      runtimeLockfile.${runtimeVersion}.tools.password
    }
    cp -r $out/temp/bin/assetcompiler/linux/x64/* $out/bin
    rm -r $out/temp
  '';
  installPhase = ''
    chmod +x $out/bin/GMAssetCompiler
    wrapProgram $out/bin/GMAssetCompiler \
    --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1 \
    --set PATH ${lib.makeBinPath [ pkgs.ffmpeg ]}
  '';
  meta = {
    mainProgram = "GMAssetCompiler";
  };
}
