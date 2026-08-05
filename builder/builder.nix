{
  pkgs,
  projectFolder,
  runtimeVersion,
  runnerPackages,
}:
let
  runtimeLockfile = builtins.fromJSON (builtins.readFile ./runtimes.lock);

  toolsZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.tools.url;
    sha256 = runtimeLockfile.${runtimeVersion}.tools.sha256;
  };
  runtimeZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.runner.url;
    sha256 = runtimeLockfile.${runtimeVersion}.runner.sha256;
  };

  gmac = import ./gmac/package.nix {
    inherit pkgs;
    inherit toolsZip;
    inherit runtimeVersion;
    inherit runtimeLockfile;
  };
  igor = import ./igor/package.nix {
    inherit pkgs;
    inherit toolsZip;
    inherit runtimeVersion;
    inherit runtimeLockfile;
  };

  enclosureZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.enclosure.url;
    sha256 = runtimeLockfile.${runtimeVersion}.enclosure.sha256;
  };

  runtimeFolder =
    pkgs.runCommand "gm-linux-runtime-v${runtimeVersion}"
      {
        buildInputs = [ pkgs.p7zip ];
      }
      ''
        mkdir -p $out
        7z -y x ${enclosureZip} -o$out -p${runtimeLockfile.${runtimeVersion}.enclosure.password}

        mkdir -p $out/bin/igor/linux
        mkdir -p $out/bin/assetcompiler/linux

        ln -s ${igor}/bin $out/bin/igor/linux/x64
        ln -s ${gmac}/bin $out/bin/assetcompiler/linux/x64

        7z -y x ${runtimeZip} BaseProject -o$out -p${runtimeLockfile.${runtimeVersion}.runner.password}
      '';

  projectName = pkgs.lib.removeSuffix ".yyp" (
    builtins.head (
      builtins.filter (filename: pkgs.lib.hasSuffix ".yyp" filename) (
        builtins.attrNames (builtins.readDir projectFolder)
      )
    )
  );

  optionsIni =
    pkgs.runCommand "${projectName}-optionsini"
      {
        buildInputs = [
          igor
        ];
      }
      ''
            # It's probably dumb that this is done just for options.ini. But from what I've seen there's some complexities to how it is generated.
            # So the fact Igor can do it is pretty nice. If it turns out it's not needed to generate it accurately for most games, we can get rid of this.
            tmp=$(mktemp -d)
            cd $tmp
            Igor \
            	-j=8 \
        	    --project=${projectFolder}/${projectName}.yyp \
        	    --rp=${runtimeFolder} \
        			Linux IniFile
           cp $tmp/output/${projectName}/options.ini $out
      '';

  assets =
    pkgs.runCommand "${projectName}-assets"
      {
        buildInputs = [
          gmac
        ];
      }
      ''
         mkdir -p $out
         cd ${projectFolder}
        	${gmac}/bin/GMAssetCompiler /c /cvm /zpex /cins /tgt=64 /mv=1 /iv=0 /rv=0 /bv=0 /j=8 /sh=True \
          	/o=$out \
           /gn=${projectName} \
           /rtp=${runtimeFolder} \
           /rt=v \
           /m=linux \
           /ic \
           /itc \
           /cd=$(mktemp -d) \
           /td=$(mktemp -d) \
           ${projectFolder}/${projectName}.yyp

         mv $out/${projectName}.unx $out/game.unx
         cp ${optionsIni} $out/options.ini
      '';

  bareRunner = pkgs.stdenvNoCC.mkDerivation {
    src = runtimeZip;
    name = "gm-linux-runner-v${runtimeVersion}";
    nativeBuildInputs = with pkgs; [
      p7zip
      autoPatchelfHook
    ];
    buildInputs = runnerPackages;
    unpackPhase = ''
      mkdir -p $out/bin
      7z -y x $src linux/runner.zip -o$out -p${runtimeLockfile.${runtimeVersion}.runner.password}
      7z -y x $out/linux/runner.zip -o$out/bin
      rm -r $out/linux
    '';
    installPhase = ''
      chmod +x $out/bin/runner
    '';
  };

  game = pkgs.stdenvNoCC.mkDerivation {
    src = assets;
    # TODO extract version from yyp
    name = projectName;

    installPhase = ''
      mkdir -p $out/bin
      ln -s $src $out/bin/assets
      cp ${bareRunner}/bin/runner $out/bin/${projectName}
    '';
    meta = {
      mainProgram = projectName;
    };
  };
in
game
