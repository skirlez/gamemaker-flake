# appimagetool is not packaged anywhere
{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  libgcrypt,
  gpgme,
  curl,
}:
stdenv.mkDerivation {
  pname = "appimagetool";
  version = "1.9.1";
  src = fetchFromGitHub {
    owner = "AppImage";
    repo = "appimagetool";
    rev = "8c8c91f762b412a19f4e8d2c4b35afb98f2d7c81";
    sha256 = "sha256-QQF2Z4U3MyhNZfAB5/zIL3mFt2ngKpI+rCD0pb6Jml4=";
  };
  nativeBuildInputs = [
    pkg-config
    cmake
  ];
  buildInputs = [
    libgcrypt
    gpgme
    curl
  ];
  strictDeps = true;
}
