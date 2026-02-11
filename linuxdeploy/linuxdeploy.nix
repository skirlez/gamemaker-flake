# linuxdeploy is not packaged anywhere
{
  pkgs,
}: 
let
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;
  excludelist = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/probonopd/AppImages/master/excludelist";
    sha256 = "sha256-UNsPiU80sWnEely8DBfbq2Hp7evKW8gmmh5qwb9L2tk=";
  };
in
  stdenv.mkDerivation {
    pname = "linuxdeploy";
    version = "1-alpha-20251107-1";
    src = pkgs.fetchFromGitHub {
      owner = "linuxdeploy";
      repo = "linuxdeploy";
      rev = "cc7b86472c3caa3fd729b9dc502fd2aa78394257";
      sha256 = "sha256-ffMVszyObwTU9IarHauk4ETnl4VfQ0Emyl+bgEO5T+k=";
      fetchSubmodules = true;
    };

    postPatch = ''
      # they fetch some file in a script at build time, not allowed with nix
      substituteInPlace src/core/generate-excludelist.sh --replace "wget --quiet \"\$url\" -O - " "cat ${excludelist}"
    '';  
    nativeBuildInputs = with pkgs; [
      bash
      pkg-config
      cmake
      wget
    ];
    buildInputs = with pkgs; [
      cimg
      libpng
      libjpeg
    ];
  }
