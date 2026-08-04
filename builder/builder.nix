{
  pkgs,
  projectFolder,
  projectName,
  runtimeVersion,
  runnerPackages,
}:
let
  runtimeLockfile = builtins.fromJSON (builtins.readFile ./runtimes.lock);

  gmac = import ./gmac/package.nix {
    inherit pkgs;
    inherit runtimeVersion;
    inherit runtimeLockfile;
  };

  enclosure-zip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.enclosure.url;
    sha256 = runtimeLockfile.${runtimeVersion}.enclosure.sha256;
  };

  enclosure =
    pkgs.runCommand "enclosure-v${runtimeVersion}"
      {
        buildInputs = [ pkgs.p7zip ];
      }
      ''
        mkdir -p $out
        7z -y x ${enclosure-zip} -o$out -p${runtimeLockfile.${runtimeVersion}.enclosure.password}
      '';

  assets = pkgs.runCommand "${projectName}-assets" { } ''
    	mkdir -p $out/cache
    	mkdir -p $out/temp
      cd ${projectFolder}

      # todo allow you to configure some of this stuff
    	${gmac}/bin/GMAssetCompiler /c /cvm /zpex /cins /tgt=64 /mv=1 /iv=0 /rv=0 /bv=0 /j=8 /sh=True \
     	/o=$out \
      /rtp=${enclosure} \
      /rt=v \
      /m=linux \
      /ic \
      /itc \
      /cd=$out/cache \
      /td=$out/temp \
     	${projectFolder}/${projectName}.yyp
      rm -r $out/cache
      rm -r $out/temp
  '';

  runner = pkgs.stdenvNoCC.mkDerivation {
    src = pkgs.fetchurl {
      url = runtimeLockfile.${runtimeVersion}.runner.url;
      sha256 = runtimeLockfile.${runtimeVersion}.runner.sha256;
    };
    name = "gm-linux-runner-v${runtimeVersion}";
    nativeBuildInputs = with pkgs; [
      p7zip
      autoPatchelfHook
    ];
    buildInputs = runnerPackages;
    unpackPhase = ''
      mkdir -p $out/bin
      7z -y x $src -o$out -p${runtimeLockfile.${runtimeVersion}.runner.password}
      ls -R $out/BaseProject 
      rm -rf $out/BaseProject
      7z -y x $out/linux/runner.zip -o$out/bin
      rm -rf $out/linux
    '';
    installPhase = ''
      mkdir -p $out/bin/assets
      cp -r ${assets}/* $out/bin/assets
      mv $out/bin/assets/${projectName}.unx $out/bin/assets/game.unx
      cat > $out/bin/assets/options.ini <<'EOF'
      [Linux]
      DisplayName="TODO"
      AppId="0"
      Icon="64.png"
      Splash="splash.png"
      MachineType="x86_64"
      EOF
      chmod +x $out/bin/runner
    '';
    meta = {
      mainProgram = "runner";
    };
  };
in
runner
