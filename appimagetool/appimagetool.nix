# appimagetool is not packaged anywhere
{
  pkgs,
}: 
let
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;
in
  stdenv.mkDerivation {
    pname = "appimagetool";
    version = "1.9.1";
    src = pkgs.fetchFromGitHub {
      owner = "AppImage";
      repo = "appimagetool";
      rev = "8c8c91f762b412a19f4e8d2c4b35afb98f2d7c81";
      sha256 = "sha256-QQF2Z4U3MyhNZfAB5/zIL3mFt2ngKpI+rCD0pb6Jml4=";
    };
    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
    ];
    buildInputs = with pkgs; [
      libgcrypt
      gpgme
      curl
    ];
  }
