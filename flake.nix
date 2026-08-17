{
  description = "A flake for the GameMaker IDE and for building and running GameMaker games";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };

      openssl-1-0 = pkgs.callPackage ./openssl-debian/package.nix { };
      debian-curl = pkgs.callPackage ./curl-debian/package.nix { };
      appimagetool = pkgs.callPackage ./appimagetool/package.nix { };

      yyc-clang = pkgs.llvmPackages.clangUseLLVM;

      # packages required to use igor
      igorPackages = (
        with pkgs;
        [
          bash
          icu
          openssl
          ffmpeg
          zlib
          unzip
          zip
        ]
      );

      # todo: use this list in makeGameMakerEnv to remove a few packages from its giant list
      runnerPackages = (
        with pkgs;
        [
          zlib
          libGL
          libGLU
          gcc.cc.lib
          openal

          openssl-1-0
          debian-curl

          libxrandr
          libxfixes
          libxxf86vm
        ]
      );

      # not yet working! hopefully I can make it work eventually
      gmrtPackages = (
        with pkgs;
        [
          dotnetCorePackages.runtime_8_0-bin

          SDL2
          zstd
          libselinux
          libxcb
          libxrender
        ]
      );

      makeGameMakerEnv =
        {
          name,
          runScript,
          extraInstallCommands ? "",
        }:
        pkgs.buildFHSEnv {
          name = name;
          targetPkgs =
            pkgs:
            (
              with pkgs;
              [
                # https://github.com/YoYoGames/GameMaker-Bugs/wiki/Ubuntu-GMS2
                openssh
                libxxf86vm
                openal
                libGL
                libGLU
                fuse

                openssl-1-0
                debian-curl

                curl

                freetype
                gtk3

                libpulseaudio
                libx11
                libxi

                # add zenity as fallback (https://github.com/YoYoGames/GameMaker-Bugs/issues/14146#issuecomment-3974129895)
                zenity

                # Gamemaker wants unshare, file for build process
                util-linux
                file

                # Required for running games (maybe)
                gmp
                gcc.cc.lib
                libxext
                libxrandr

                e2fsprogs
                libgpg-error

                # required for yyc
                libxfixes

                # Seems to work without, but log errors about it missing
                procps # for pidof

                # make "show in file manager" work, and allow gamemaker to open your browser
                xdg-utils

                # yyc shits
                gnumake
                binutils

                # linuxdeploy wants it
                patchelf

                # appimagetool wants it
                squashfsTools
                desktop-file-utils
                zsync

                # wants these since at least ide-2024-1400-0-904
                libpng
                brotli
              ]
              ++ igorPackages # ++ gmrtPackages
            );
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

            # GMRT needs the dotnet 8 runtime. Seems like it can find it with this unset,
            # but users may have it set and make it look elsewhere instead which is bad
            # unset DOTNET_ROOT
          '';
          runScript = runScript;
          extraInstallCommands = extraInstallCommands;
          extraBuildCommands = ''
            mkdir $out/opt

            # gamemaker, by default, sets this path as the path to chroot to when building.
            # in order to make it easier for the user we just symlink it to the FHS env root, which is what we want
            ln -s .. $out/opt/steam-runtime

            # gamemaker expects clang-3.8 to build for YYC.
            # Usually it gets a weird version of clang 3.8 from steam-runtime: https://repo.steampowered.com/steamrt-images-scout/snapshots/latest-public-stable/sources/
            # TODO: We could probably build this version ourselves pulling patches from the debian archive.
            # We make this wrapper script to point it to the latest clang instead, which seems to work, but as you can see below it requires a bit of a hack.

            cat << 'EOF' > $out/usr/bin/clang-3.8
              #!${pkgs.bash}/bin/bash
               
              # extra arguments:
              # -no-pie
              # fixed some error ide-2024-1400-4-986
              # 
              # -Wno-non-pod-varargs
              # this warning made compilation stop
                      
              EXTRA="-no-pie -Wno-non-pod-varargs"
              
              # I'm not sure why but sometimes gamemaker emits this exact list of parameters and it requires fixing up
              if [[ "$*" == "-std=c++14 -m64 -O3 -Wno-deprecated-writable-strings -I Game -o out/pch.hpp.pch Game/pch.hpp -I . -DYYLLVM" ]]; then
                bash ${yyc-clang}/bin/clang -x c++-header $EXTRA "$@"
                exit
              fi
              echo $EXTRA
              bash ${yyc-clang}/bin/clang $EXTRA "$@"
            EOF
            chmod +x $out/usr/bin/clang-3.8

            # clang looks here
            # (it looks in /usr/lib/x86_64-linux-gnu but lib links to lib64)
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

            # TODO: starting 2026.100.0.1083 prints out an exception following the invokation of appimagetool. But only sometimes! and the build still works
            # (could be a gamemaker bug, it is a beta after all)


            # same idea for linuxdeploy. the IDE runs --appimage-extract, then inserts the extracted FHS environment to PATH.
            # it isn't an appimage for us, so when it tries doing that just exit, otherwise just run
            cat << 'EOF' > $out/usr/bin/linuxdeploy
              #!${pkgs.bash}/bin/bash
              [ "$1" = "--appimage-extract" ] && exit
              exec ${pkgs.linuxdeploy}/bin/linuxdeploy "$@"
            EOF
            chmod +x $out/usr/bin/linuxdeploy
          '';
        };

      makeGameMakerPackage =
        {
          version,
          deb-hash,
          use-archive ? true,
          type ? "beta",
          lts-year ? "",
        }:
        let
          prefix =
            if type == "beta" then
              "Beta-"
            else if type == "lts" then
              "LTS${lts-year}-"
            else
              "";

          suffix =
            if type == "beta" then
              "-Beta"
            else if type == "lts" then
              "-LTS${lts-year}"
            else
              "";

          display-name-insert =
            if type == "beta" then
              "Beta "
            else if type == "lts" then
              "LTS ${lts-year} "
            else
              "";

          ide = pkgs.stdenv.mkDerivation rec {
            pname = "gamemaker-ide";
            inherit version;

            src =
              if use-archive then
                pkgs.fetchurl {
                  url = "https://github.com/Skirlez/gamemaker-ubuntu-archive/releases/download/v${version}/GameMaker-${prefix}${version}.deb";
                  sha256 = deb-hash;
                }
              else
                pkgs.fetchurl {
                  url = "https://gms.yoyogames.com/GameMaker-${prefix}${version}.deb";
                  sha256 = deb-hash;
                };

            nativeBuildInputs = [ pkgs.dpkg ];
            unpackPhase = ''
              mkdir ./unpacked
              dpkg -x $src ./unpacked
              rm -rf ./unpacked/opt/GameMaker${suffix}/armv7l
              rm -rf ./unpacked/opt/GameMaker${suffix}/aarch64
              rm -rf ./unpacked/usr/
            '';
            installPhase = ''
              runHook preInstall
              mkdir $out
              cp -r ./unpacked/* $out/
              runHook postInstall
            '';
          };
        in
        makeGameMakerEnv {
          name = "gamemaker-${version}";
          runScript = "${ide}/opt/GameMaker${suffix}/GameMaker";
          extraInstallCommands = ''
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/256x256/apps

            cp ${ide}/opt/GameMaker${suffix}/GameMaker.png $out/share/icons/hicolor/256x256/apps/gamemaker-${version}.png

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

      genericGameMakerFHSEnv = makeGameMakerEnv {
        name = "gamemaker-env";
        runScript = "bash";
      };

      dev = pkgs.mkShell {
        shellHook = ''
          exec ${genericGameMakerFHSEnv}/bin/gamemaker-env
        '';
      };

      igorFHSEnv = pkgs.buildFHSEnv {
        name = "igor-env";
        targetPkgs = pkgs: igorPackages;
      };

      igor = pkgs.mkShell {
        shellHook = ''
          exec ${igorFHSEnv}/bin/igor-env
        '';
      };

      ide-2023-4-0-84 = makeGameMakerPackage {
        version = "2023.4.0.84";
        deb-hash = "024z7ybljd63np14ny3r55knr2cc2b3zlafl73yzk9xj1sa1ldr5";
        type = "internal-normal";
      };
      ide-2023-8-2-108 = makeGameMakerPackage {
        version = "2023.8.2.108";
        deb-hash = "0r64ipsky8azk9vqlxf31kc74af5hplm5n7n2k5z14cycnmiryk4";
        type = "internal-normal";
      };
      ide-2023-11-1-129 = makeGameMakerPackage {
        version = "2023.11.1.129";
        deb-hash = "16gqpczwr1jas4r95wc5a5qjqsb9clpshi66h2g6l89dgd722sr8";
        type = "internal-normal";
      };

      ide-2024-13-1-193 = makeGameMakerPackage {
        version = "2024.13.1.193";
        deb-hash = "sha256-Vjflzn6r5Quy+NldjGw/ZXiNyNeDpj7+FjD0i/FDG/s=";
        type = "internal-normal";
      };

      /*
        as far as i can tell this version is straight up broken
        ide-2024-1300-0-785 = (makeGamemakerPackage { version = "2024.1300.0.785"; deb-hash="1kygsajq3jgsjfrwsqhy8ss9r3696p4yag86qlrqdfr4kjrjdgdh"; use-archive=false; }).env;
      */
      ide-2023-400-0-324 = makeGameMakerPackage {
        version = "2023.400.0.324";
        deb-hash = "08zz0ff7381259kj2gnnlf32p5w8hz6bqhz7968mw0i7z0p6w8hc";
        type = "beta";
      };
      ide-2026-100-0-1121 = makeGameMakerPackage {
        version = "2026.100.0.1121";
        deb-hash = "sha256-OOh4A3BgtDyn0B0lmfyiZ/Sv1ze1cShNLuXr9G68sSk=";
        type = "beta";
        use-archive = false;
      };
      ide-2026-0-0-16 = makeGameMakerPackage {
        version = "2026.0.0.16";
        deb-hash = "sha256-Uh2zCmk6FrqniXAFmHEkvqKTorvL4KmO3CWDcqsXErE=";
        type = "lts";
        lts-year = "2026";
        use-archive = false;
      };

      builder =
        {
          src,
          runtimeVersion,
          configuration ? "Default"
        }:
        import ./builder/builder.nix {
          projectFolder = src;
          inherit runtimeVersion;
          inherit configuration;
          inherit pkgs;
          inherit runnerPackages;
        };

    in
    {
      devShells.x86_64-linux = {
        default = dev;
        igor = igor;
      };

      packages.x86_64-linux = {
        buildGameMakerProject = builder;

        default = ide-2026-0-0-16;

        ide-lts-2026 = ide-2026-0-0-16;

        ide-latest-beta = ide-2026-100-0-1121;
        inherit ide-2023-400-0-324;

        inherit ide-2023-4-0-84;
        inherit ide-2023-8-2-108;
        inherit ide-2023-11-1-129;
        inherit ide-2024-13-1-193;
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
