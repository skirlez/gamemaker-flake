# linuxdeploy is not packaged anywhere
{
  pkgs,
}: 
let
	# This could update some day (https://github.com/AppImageCommunity/pkg2appimage)
  excludelist = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/AppImageCommunity/pkg2appimage/19e30b276ffedf4d3b4b56bc6320f463625a74f8/excludelist";
    sha256 = "sha256-UNsPiU80sWnEely8DBfbq2Hp7evKW8gmmh5qwb9L2tk=";
  };
  
in
  pkgs.stdenv.mkDerivation {
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
      # they fetch this file in a script at build time, not allowed with nix
      substituteInPlace src/core/generate-excludelist.sh --replace "wget --quiet \"\$url\" -O - " "cat ${excludelist}"
    '';  
    nativeBuildInputs = with pkgs; [
      bash
      pkg-config
      cmake
    ];
    buildInputs = with pkgs; [
      cimg
      libpng
      libjpeg
    ];
  }
