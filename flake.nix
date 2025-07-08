# TODO GOALS

# 1. I don't think you're meant to package linuxdeploy like that. It'd be great if it used pkgs.appimageTools.wrapType2 like appimagetool - but that doesn't seem to work.
# 2. Support for more architectures
# 3. Add support for YYC

{
  description = "A flake for the GameMaker IDE and GameMaker games";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # current nixpkgs does not package OpenSSL 1.0.x
    nixpkgs-openssl.url =
      "github:NixOS/nixpkgs?ref=d1c3fea7ecbed758168787fe4e4a3157e52bc808";

    # major shoutouts to https://github.com/MichailiK/yoyo-games-runner-nix/blob/main/flake.nix ^
  };

  outputs = { self, nixpkgs, nixpkgs-openssl }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };

      pkgs-openssl = import nixpkgs-openssl {
        inherit system;
        # TODO: is this necessary? I can't include the package in my system packages otherwise.
        config.permittedInsecurePackages = [ "openssl-1.0.2u" ];
      };
      openssl_1_0 = pkgs-openssl.openssl_1_0_2;

      appimagetool = pkgs.appimageTools.wrapType2 {
        pname = "appimagetool";
        version = "1.9.0";
        src = pkgs.fetchurl {
          url =
            "https://github.com/AppImage/appimagetool/releases/download/1.9.0/appimagetool-x86_64.AppImage";
          sha256 = "1lc3c38033392x5lnr1z4jmqx3fryfqczbv1bda6wzsc162xgza6";
        };
        extraPkgs = pkgs: with pkgs; [ file appstream gnupg ];
      };

      /* linuxdeploy = pkgs.appimageTools.wrapType2 {
           pname = "linuxdeploy";
           version = "1-alpha-20250213-2";
           src = pkgs.fetchurl {
             url = "https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20250213-2/linuxdeploy-x86_64.AppImage";
             sha256 = "0ajjnk89zbgjwvbkfxm7cm9hwr32yi80vhv7ks0izwrymdwg4j26";
           };
           extraPkgs = pkgs: [ ];
         };
      */

      linuxdeploy = pkgs.stdenv.mkDerivation {
        name = "linuxdeploy";
        version = "1-alpha-20250213-2";
        src = pkgs.fetchurl {
          url =
            "https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20250213-2/linuxdeploy-x86_64.AppImage";
          sha256 = "0ajjnk89zbgjwvbkfxm7cm9hwr32yi80vhv7ks0izwrymdwg4j26";
        };
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/linuxdeploy
          chmod +x $out/bin/linuxdeploy
        '';
      };

      makeGamemakerFhs = { name, runScript, extraInstallCommands ? "" }:
        pkgs.buildFHSEnv {
          name = name;
          targetPkgs = pkgs:
            (with pkgs; [
              # https://gamemaker.zendesk.com/hc/en-us/articles/235186168-Setting-Up-For-Ubuntu
              openssh
              openssl_1_0
              xorg.libXxf86vm
              openal
              libGL
              libGLU
              zlib
              (pkgs.callPackage ./debian/libcurl3-gnutls.nix { })
              ffmpeg_6
              fuse
              icu

              freetype
              gtk3

              libpulseaudio
              xorg.libX11
              xorg.libXi

              # Gamemaker wants unshare, file for build process
              util-linux
              file

              # For building games with zip
              zip
              unzip

              # Required for running games (maybe)
              libz
              gmp
              gcc.cc.lib
              xorg.libXext
              xorg.libXrandr
              e2fsprogs
              libgpg-error
              ffmpeg_4.lib

              # Seems to work without, but log errors about it missing
              procps # for pidof

              # show in file manager
              xdg-utils

              appimagetool
              linuxdeploy

              # yyc shits
              gnumake
              # need to get clang-3.8
            ]);
          profile = ''

            export LD_LIBRARY_PATH=/lib
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib/x86_64-linux-gnu

            # We have to include the run directory because gamemaker expects to find xdg-open. Not very Reproducible but you know
            export PATH="/bin:/usr/bin:/run/current-system/sw/bin/"
          '';
          runScript = runScript;
          extraInstallCommands = extraInstallCommands;
        };

      makeGamemakerPackageFromBeta =
        { version, beta-version, deb-hash, use-archive ? true }:
        let
          ide = pkgs.stdenv.mkDerivation rec {
            pname = "gamemaker-ide";
            inherit version;

            src = if use-archive then
              pkgs.fetchurl {
                url =
                  "https://github.com/Skirlez/gamemaker-ubuntu-archive/releases/download/${beta-version}/GameMaker-Beta-${beta-version}.deb";
                sha256 = deb-hash;
              }
            else
              pkgs.fetchurl {
                url =
                  "https://gms.yoyogames.com/GameMaker-Beta-${beta-version}.deb";
                sha256 = deb-hash;
              };

            nativeBuildInputs = [ pkgs.dpkg pkgs.python314 ];

            conversion-script = ./convert-beta-to-regular.py;
            regular-ico = ./assets/GameMaker.ico;
            regular-png = ./assets/GameMaker.png;
            splash-folder = ./assets/Splash;
            unpackPhase = ''
              mkdir ./unpacked
              dpkg -x $src ./unpacked
              rm -rf ./unpacked/opt/GameMaker-Beta/armv7l
              rm -rf ./unpacked/opt/GameMaker-Beta/aarch64
              rm -rf ./unpacked/usr/
            '';
            installPhase = ''
              runHook preInstall
              mkdir $out
              cp -r ./unpacked/* $out/
              python3 ${conversion-script} ${beta-version} ${version} $out
              cp ${regular-ico} $out/opt/GameMaker-Beta/x86_64/GameMaker.ico
              cp -r ${splash-folder}/* $out/opt/GameMaker-Beta/x86_64/Splash/
              cp ${regular-png} $out/opt/GameMaker-Beta/GameMaker.png
              runHook postInstall
            '';
          };
        in {
          env = makeGamemakerFhs {
            name = "gamemaker-${version}";
            runScript = "${ide}/opt/GameMaker-Beta/GameMaker";
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/256x256/apps

              cp ${ide}/opt/GameMaker-Beta/GameMaker.png $out/share/icons/hicolor/256x256/apps/gamemaker-${version}.png

              cat <<EOF > "$out/share/applications/gamemaker-${version}.desktop"
              [Desktop Entry]
              Exec=gamemaker-${version}
              Icon=gamemaker-${version}
              Name=GameMaker v${version}
              Categories=Development
              Comment=2D Game Engine IDE
              Type=Application
              StartupWMClass=GameMaker
              EOF
            '';
          };
        };

      makeGamemakerPackage = { version, deb-hash, use-archive ? true }:
        let
          ide = pkgs.stdenv.mkDerivation rec {
            pname = "gamemaker-ide";
            inherit version;

            src = if use-archive then
              pkgs.fetchurl {
                url =
                  "https://github.com/Skirlez/gamemaker-ubuntu-archive/releases/download/${version}/GameMaker-Beta-${version}.deb";
                sha256 = deb-hash;
              }
            else
              pkgs.fetchurl {
                url = "https://gms.yoyogames.com/GameMaker-Beta-${version}.deb";
                sha256 = deb-hash;
              };

            nativeBuildInputs = [ pkgs.dpkg ];
            unpackPhase = ''
              mkdir ./unpacked
              dpkg -x $src ./unpacked
              rm -rf ./unpacked/opt/GameMaker-Beta/armv7l
              rm -rf ./unpacked/opt/GameMaker-Beta/aarch64
              rm -rf ./unpacked/usr/
            '';
            installPhase = ''
              runHook preInstall
              mkdir $out
              cp -r ./unpacked/* $out/
              runHook postInstall
            '';
          };
        in {
          env = makeGamemakerFhs {
            name = "gamemaker-${version}";
            runScript = "${ide}/opt/GameMaker-Beta/GameMaker";
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/256x256/apps

              cp ${ide}/opt/GameMaker-Beta/GameMaker.png $out/share/icons/hicolor/256x256/apps/gamemaker-${version}.png

              cat <<EOF > "$out/share/applications/gamemaker-${version}.desktop"
              [Desktop Entry]
              Exec=gamemaker-${version}
              Icon=gamemaker-${version}
              Name=GameMaker Beta v${version}
              Categories=Development
              Comment=2D Game Engine IDE
              Type=Application
              StartupWMClass=GameMaker
              EOF
            '';
          };
        };

      generic-gamemaker-fhs-env = makeGamemakerFhs {
        name = "gamemaker-env";
        runScript = "bash";
      };

      dev = pkgs.mkShell {
        shellHook = ''
          exec ${generic-gamemaker-fhs-env}/bin/gamemaker-env
        '';
      };
      /* # libraries required for gaming
         gaming-libs = with pkgs; [
           openssl_1_0
           (pkgs.callPackage ./debian/libcurl3-gnutls.nix { })
           xorg.libX11
           xorg.libXext
           xorg.libXrandr
           xorg.libXxf86vm
           e2fsprogs
           libGL
           libGLU
           gmp
           libgpg-error
           libz
           gcc.cc.lib #  libstdc++.so.6?
           openal # not in ldd, but required for audio
           ffmpeg_4.lib
         ];
         gaming = pkgs.mkShell {
           buildInputs = gaming-libs;
           shellHook = ''
             export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath gaming-libs}
           '';
         };
      */

      ide-2023-400-0-324 = (makeGamemakerPackage {
        version = "2023.400.0.324";
        deb-hash = "08zz0ff7381259kj2gnnlf32p5w8hz6bqhz7968mw0i7z0p6w8hc";
      }).env;
      ide-2023-4-0-84 = (makeGamemakerPackageFromBeta {
        version = "2023.4.0.84";
        beta-version = "2023.400.0.324";
        deb-hash = "08zz0ff7381259kj2gnnlf32p5w8hz6bqhz7968mw0i7z0p6w8hc";
      }).env;

      /* as far as i can tell this version is straight up broken
         ide-2024-1300-0-785 = (makeGamemakerPackage { version = "2024.1300.0.785"; deb-hash="1kygsajq3jgsjfrwsqhy8ss9r3696p4yag86qlrqdfr4kjrjdgdh"; use-archive=false; }).env;
         ide-2024-13-1-193 = (makeGamemakerPackageFromBeta {
           version = "2024.13.1.193"; beta-version = "2024.1300.0.785"; deb-hash="1kygsajq3jgsjfrwsqhy8ss9r3696p4yag86qlrqdfr4kjrjdgdh"; use-archive=false;  }
         ).env;
      */
      ide-2024-1400-0-841 = (makeGamemakerPackage {
        version = "2024.1400.0.841";
        deb-hash = "0d0yrvpfhxhz1492q5j0a58y99ks6sbzdw4fv9qqmj8iml0c6hi9";
        use-archive = false;
      }).env;

    in {
      devShell.x86_64-linux = dev;

      packages.x86_64-linux = {
        #ide-latest = ide-2024-13-1-193;
        ide-latest-beta = ide-2024-1400-0-841;

        inherit ide-2023-400-0-324;
        inherit ide-2023-4-0-84;

        #inherit ide-2024-1300-0-785;
        #inherit ide-2024-13-1-193;

        inherit ide-2024-1400-0-841;
      };

    };
}
