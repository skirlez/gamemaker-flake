# GameMaker depends curl with debian versioning
{
	pkgs,
}: 
let
	debianPatchesSource = builtins.fetchTarball {
		url = "http://deb.debian.org/debian/pool/main/c/curl/curl_7.88.1-10+deb12u14.debian.tar.xz";
		sha256 = "sha256:0ha2mn84brjpiydxr7zl48ij0dv2mnz7piwgdbc4dcjns6rb78vx";
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
	stdenv.mkDerivation {
		pname = "libcurl3-gnutls";
		version = "7.88.1-debian";
		src = builtins.fetchTarball {
			url = "https://github.com/curl/curl/releases/download/curl-7_88_1/curl-7.88.1.tar.gz";
			sha256 = "sha256:1442d7h013q9wlw3mxjkqihf6wxwmyf5yz88wq289fzj53ca1s03";
		};
		strictDeps = true;
		patches = debianPatches;
		configureFlags = [
			"--enable-versioned-symbols"
	    "--disable-manual"
		  "--with-gnutls=${lib.getDev pkgs.gnutls}"
		];
		buildInputs = with pkgs; [
			gnutls
		];
		installPhase = ''
			mkdir -p $out/lib
			cp lib/.libs/libcurl.so $out/lib/libcurl-gnutls.so.4
		'';
	}
