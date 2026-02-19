# openssl 1.0.2 is no longer in nixpkgs, and also, when building normally, its symbols aren't versioned,
# and debian has patches that make them versioned. going by the steam runtime, looks like it depends on 
# the ubuntu version of openssl 1.0.1. so this is close enough anyway
{ 
  pkgs,
}:
let
  debianPatchesSource = builtins.fetchTarball {
    url = "https://snapshot.debian.org/archive/debian-archive/20190328T105444Z/debian/pool/main/o/openssl/openssl_1.0.2l-1~bpo8%2B1.debian.tar.xz";
    sha256 = "sha256:0csszd6cnl6m1xgq0llrygyqcad1bmng3ffvndpza0jcw05jmra9";
  };
  series = builtins.readFile "${debianPatchesSource}/patches/series";
  debianPatches = map (p: "${debianPatchesSource}/patches/${p}")
    (builtins.filter (line: builtins.isString line # for some reason the split string list contains substrings, and more lists? I don't really get it
                      && builtins.substring 0 1 line != "#" 
                      && builtins.stringLength line != 0) 
                        (builtins.split "\n" series));
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;
in
pkgs.stdenv.mkDerivation {
  pname = "openssl";
  version = "1.0.2l";
  
  src = pkgs.fetchurl {
    url = "https://www.openssl.org/source/openssl-1.0.2l.tar.gz";
    sha256 = "sha256-zgcZW2WedfTh20NVKGAHAGHxVqmLs3tnKxAbpuPd8ww=";
  };
  
  patches = debianPatches;
  nativeBuildInputs = [
    pkgs.perl
  ];
  configureScript = "./Configure shared linux-x86_64";
  
  # grab only what we need
  installPhase = ''
    mkdir -p $out/lib
    cp libcrypto.so.1.0.0 $out/lib/libcrypto.so
    cp libssl.so.1.0.0 $out/lib/libssl.so
    cp libcrypto.so.1.0.0 $out/lib/libcrypto.so.1.0.0
    cp libssl.so.1.0.0 $out/lib/libssl.so.1.0.0
  '';
}
