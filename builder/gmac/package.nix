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
    _7zz
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
    tmp=$(mktemp -d)
    7zz -y x $src bin/assetcompiler/linux/x64 -o$tmp -p${
      runtimeLockfile.${runtimeVersion}.tools.password
    }
    mv $tmp/bin/assetcompiler/linux/x64/* $out/bin
  '';
  installPhase = ''
    chmod +x $out/bin/GMAssetCompiler
    wrapProgram $out/bin/GMAssetCompiler \
      --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1 \
      --set PATH ${lib.makeBinPath [ pkgs.ffmpeg ]} \
      --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ pkgs.openssl ]}
  '';
  meta = {
    mainProgram = "GMAssetCompiler";
  };
}
