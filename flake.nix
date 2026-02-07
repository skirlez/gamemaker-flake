{
  description = "A flake for the GameMaker IDE and GameMaker games";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # current nixpkgs does not package OpenSSL 1.0.x
    # major shoutouts to https://github.com/MichailiK/yoyo-games-runner-nix/blob/main/flake.nix
    nixpkgs-openssl.url = "github:NixOS/nixpkgs?ref=d1c3fea7ecbed758168787fe4e4a3157e52bc808";

    nixpkgs-curl3.url = "github:NixOS/nixpkgs?ref=1715c13faa2632c0157435babda955fbc3e27cd7";
  };

  outputs = { self, nixpkgs, nixpkgs-openssl, nixpkgs-curl3 }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };

      pkgs-openssl = import nixpkgs-openssl {
        inherit system;
        # TODO: is this necessary? I can't include the package in my system packages otherwise.
        config.permittedInsecurePackages = [ "openssl-1.0.2u" ];
      };
      pkgs-curl3 = import nixpkgs-curl3 {
        inherit system;
      };

      openssl_1_0 = pkgs-openssl.openssl_1_0_2;
      special-curl = pkgs-curl3.curlWithGnuTls;

      yyc-clang = pkgs.llvmPackages.clangUseLLVM;


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

      # packages required to use igor
      igorPackages = (with pkgs; [
        bash
        icu
        openssl
        ffmpeg
        zlib
        unzip
        zip
      ]);


      makeGamemakerEnv = { name, runScript, extraInstallCommands ? "" }:
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
              fuse

              special-curl
              
              freetype
              gtk3

              libpulseaudio
              xorg.libX11
              xorg.libXi

              # Gamemaker wants unshare, file for build process
              util-linux
              file

              # Required for running games (maybe)
              libz
              gmp
              gcc.cc.lib
              xorg.libXext
              xorg.libXrandr

              e2fsprogs
              libgpg-error

              # required for yyc
              xorg.libXfixes

              # Seems to work without, but log errors about it missing
              procps # for pidof

              # make "show in file manager" work, and allow gamemaker to open your browser
              xdg-utils

              linuxdeploy

              # yyc shits
              gnumake
              binutils

              # wants these since at least ide-2024-1400-0-904
              libpng
              brotli
            ] ++ igorPackages);
          profile = ''
            export LD_LIBRARY_PATH=/lib
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib/x86_64-linux-gnu

            # We have to include the run directory because gamemaker uses xdg-open, which expects to find whatever your system's way
            # is of opening a folder (kde-open for me). Not very Reproducible but you know
            export PATH="/bin:/usr/bin:/run/current-system/sw/bin/"


            # TODO check if this is still required for clang to behave
            unset TMPDIR

            # errors about it at least on 2023.11
            unset SOURCE_DATE_EPOCH
          '';
          runScript = runScript;
          extraInstallCommands = extraInstallCommands;
          extraBuildCommands = ''
            mkdir $out/opt

            # gamemaker, by default, sets this path as the path to chroot to when building.
            # in order to make it easier for the user we just symlink it to the FHS env root, which is what we want
            ln -s .. $out/opt/steam-runtime

            # gamemaker expects clang-3.8.
            # Usually it gets a weird version of clang 3.8 from steam-runtime. Its behavior did not match any clang 3.8 version I got
            # from old nixpkgs. We make this wrapper script to point it to the latest clang instead, which seems to work OK.

            cat << 'EOF' > $out/usr/bin/clang-3.8
              #!${pkgs.bash}/bin/bash
              # -no-pie
              # fix some error ide-2024-1400-4-986
              # 
              # -Wno-non-pod-varargs
              # this warning made compilation stop
                      
              EXTRA="-no-pie -Wno-non-pod-varargs"
              

              # We check for the parameters used in the first invocation, and add some of our own, which seems to sort an error out.
              # TODO: more research on why this isn't needed for steam-runtime's clang
              if [[ "$*" == "-std=c++14 -m64 -O3 -Wno-deprecated-writable-strings -I Game -o out/pch.hpp.pch Game/pch.hpp -I . -DYYLLVM" ]]; then
                bash ${yyc-clang}/bin/clang -x c++-header $EXTRA "$@"
                exit
              fi
              echo $EXTRA
              bash ${yyc-clang}/bin/clang $EXTRA "$@"
            EOF

            chmod +x $out/usr/bin/clang-3.8

            # clang looks here (TODO check if this is still required)
            # (looks in /usr/lib/x86_64-linux-gnu but lib links to lib64)
            ln -s ../lib64 $out/usr/lib64/x86_64-linux-gnu

            # expose system fonts
            ln -s /run/current-system/sw/share/X11/fonts $out/usr/share/fonts

            # starting from 2024.1400.0.865, the IDE attempts to avoid fusermount by running appimagetool with --appimage-extract-and-run. We have it wrapped with wrapType2, so we actually
            # don't want it to pass that flag, since it's a normal binary now (and the argument gets passed to appimagetool, and it fails). So we have to create this script to discard that flag.
            cat << 'EOF' > $out/usr/bin/appimagetool
              #!${pkgs.bash}/bin/bash
              [ "$1" = "--appimage-extract-and-run" ] && shift
              exec ${appimagetool}/bin/appimagetool "$@"
            EOF

            chmod +x $out/usr/bin/appimagetool
          '';
        };

      makeGamemakerPackage = { version, deb-hash, use-archive ? true, internal-normal ? false }:
        let
          beta-prefix = if internal-normal then "" else "Beta-";
          beta-suffix = if internal-normal then "" else "-Beta";
          display-name-insert = if internal-normal then "" else "Beta ";
          ide = pkgs.stdenv.mkDerivation rec {
            pname = "gamemaker-ide";
            inherit version;

            src = if use-archive then
              pkgs.fetchurl {
                url =
                  "https://github.com/Skirlez/gamemaker-ubuntu-archive/releases/download/v${version}/GameMaker-${beta-prefix}${version}.deb";
                sha256 = deb-hash;
              }
            else
              pkgs.fetchurl {
                url = "https://gms.yoyogames.com/GameMaker-${beta-prefix}${version}.deb";
                sha256 = deb-hash;
              };

            nativeBuildInputs = [ pkgs.dpkg ];
            unpackPhase = ''
              mkdir ./unpacked
              dpkg -x $src ./unpacked
              rm -rf ./unpacked/opt/GameMaker${beta-suffix}/armv7l
              rm -rf ./unpacked/opt/GameMaker${beta-suffix}/aarch64
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
          env = makeGamemakerEnv {
            name = "gamemaker-${version}";
            runScript = "${ide}/opt/GameMaker${beta-suffix}/GameMaker";
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/256x256/apps

              cp ${ide}/opt/GameMaker${beta-suffix}/GameMaker.png $out/share/icons/hicolor/256x256/apps/gamemaker-${version}.png

              cat <<EOF > "$out/share/applications/gamemaker-${version}.desktop"
              [Desktop Entry]
              Exec=gamemaker-${version}
              Icon=gamemaker-${version}
              Name=GameMaker ${display-name-insert}v${version}
              Categories=Development
              Comment=2D Game Engine IDE
              Type=Application
              StartupWMClass=GameMaker
              EOF
            '';
          };
        };

      generic-gamemaker-fhs-env = makeGamemakerEnv {
        name = "gamemaker-env";
        runScript = "bash";
      };

      dev = pkgs.mkShell {
        shellHook = ''
          exec ${generic-gamemaker-fhs-env}/bin/gamemaker-env
        '';
      };

      igor-fhs-env = pkgs.buildFHSEnv {
        name = "igor-env";
        targetPkgs = pkgs: igorPackages;
      };


      igor = pkgs.mkShell {
        shellHook = ''
          exec ${igor-fhs-env}/bin/igor-env
        '';
      };


      ide-2023-4-0-84 = (makeGamemakerPackage {
        version = "2023.4.0.84";
        deb-hash = "024z7ybljd63np14ny3r55knr2cc2b3zlafl73yzk9xj1sa1ldr5";
        internal-normal = true;
      }).env;
      ide-2023-8-2-108 = (makeGamemakerPackage {
        version = "2023.8.2.108";
        deb-hash = "0r64ipsky8azk9vqlxf31kc74af5hplm5n7n2k5z14cycnmiryk4";
        internal-normal = true;
      }).env;
      ide-2023-11-1-129 = (makeGamemakerPackage {
        version = "2023.11.1.129";
        deb-hash = "16gqpczwr1jas4r95wc5a5qjqsb9clpshi66h2g6l89dgd722sr8";
        internal-normal = true;
      }).env;

      ide-2024-13-1-193 = (makeGamemakerPackage {
        version = "2024.13.1.193";
        deb-hash = "sha256-Vjflzn6r5Quy+NldjGw/ZXiNyNeDpj7+FjD0i/FDG/s=";
        internal-normal = true;
      }).env;


      /* as far as i can tell this version is straight up broken
         ide-2024-1300-0-785 = (makeGamemakerPackage { version = "2024.1300.0.785"; deb-hash="1kygsajq3jgsjfrwsqhy8ss9r3696p4yag86qlrqdfr4kjrjdgdh"; use-archive=false; }).env;
      */
      ide-2023-400-0-324 = (makeGamemakerPackage {
        version = "2023.400.0.324";
        deb-hash = "08zz0ff7381259kj2gnnlf32p5w8hz6bqhz7968mw0i7z0p6w8hc";
      }).env;
      ide-2024-1400-4-986 = (makeGamemakerPackage {
        version = "2024.1400.4.986";
        deb-hash = "sha256-LC/V58UDSc6RUgj42Aafnuoj4t6GV5jpf+/3gaF7WlM=";
        use-archive = false;
      }).env;


    in {
      devShells.x86_64-linux = {
        default = dev;
        igor = igor;
      };

      packages.x86_64-linux = {
        default = ide-2024-1400-4-986;

        ide-latest = ide-2024-13-1-193;
        ide-latest-beta = ide-2024-1400-4-986;

        inherit ide-2023-400-0-324;
        inherit ide-2024-1400-4-986;

        inherit ide-2023-4-0-84;
        inherit ide-2023-8-2-108;
        inherit ide-2023-11-1-129;
        inherit ide-2024-13-1-193;
      };
    };
}
