{
  pkgs,
  projectFolder,
  configuration,
  runnerPackages,
  providedRuntimeVersion ? "",
}:
let
  lib = pkgs.lib;
  runtimeLockfile = builtins.fromJSON (builtins.readFile ./runtimes.lock);

  projectName = lib.removeSuffix ".yyp" (
    builtins.head (
      builtins.filter (filename: lib.hasSuffix ".yyp" filename) (
        builtins.attrNames (builtins.readDir projectFolder)
      )
    )
  );

  yyp = builtins.fromJSON (
    builtins.readFile (
      import ./yyp-fixer {
        inherit projectFolder;
        inherit projectName;
        inherit pkgs;
      }
    )
  );

  IDEVersionMajorMinor = lib.take 2 (builtins.splitVersion yyp.MetaData.IDEVersion);
  runtimeVersionPrefix = builtins.concatStringsSep "." IDEVersionMajorMinor;
  runtimeVersionCandidates = builtins.filter (version: lib.hasPrefix runtimeVersionPrefix version) (
    builtins.attrNames runtimeLockfile
  );
  sortedRuntimeVersions = builtins.sort (
    p: q: builtins.compareVersions p q > 0
  ) runtimeVersionCandidates;
  runtimeVersionGuess =
    lib.throwIf (sortedRuntimeVersions == [ ])
      "Project builder could not the guess runtime version (no runtimes beginning with \"${runtimeVersionPrefix}\" found). Please supply the runtimeVersion attribute manually."
      builtins.head
      sortedRuntimeVersions;

  runtimeVersion =
    if providedRuntimeVersion != "" then
      providedRuntimeVersion
    else
      builtins.traceVerbose "Runtime version chosen: ${runtimeVersionGuess}" runtimeVersionGuess;

  toolsZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.tools.url;
    sha256 = runtimeLockfile.${runtimeVersion}.tools.sha256;
  };
  runtimeZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.runner.url;
    sha256 = runtimeLockfile.${runtimeVersion}.runner.sha256;
  };
  enclosureZip = pkgs.fetchurl {
    url = runtimeLockfile.${runtimeVersion}.enclosure.url;
    sha256 = runtimeLockfile.${runtimeVersion}.enclosure.sha256;
  };
  gmac = import ./gmac/package.nix {
    inherit pkgs;
    inherit toolsZip;
    runtimeVersion = runtimeVersion;
    inherit runtimeLockfile;
  };
  igor = import ./igor/package.nix {
    inherit pkgs;
    inherit toolsZip;
    runtimeVersion = runtimeVersion;
    inherit runtimeLockfile;
  };

  runtimeFolder =
    pkgs.runCommand "gm-linux-runtime-${runtimeVersion}"
      {
        nativeBuildInputs = [
          pkgs._7zz
        ];
      }
      ''
        echo $out
        7zz -y x ${enclosureZip} -o$out -p${runtimeLockfile.${runtimeVersion}.enclosure.password}

        rm -rf $out/bin/igor/linux
        rm -rf $out/bin/assetcompiler/linux
        rm -rf $out/bin/igor/windows
        rm -rf $out/bin/assetcompiler/windows
        rm -rf $out/bin/igor/osx
        rm -rf $out/bin/assetcompiler/osx

        mkdir -p $out/bin/igor/linux
        mkdir -p $out/bin/assetcompiler/linux
        ln -s ${igor}/bin $out/bin/igor/linux/x64
        ln -s ${gmac}/bin $out/bin/assetcompiler/linux/x64

        7zz -y x ${runtimeZip} BaseProject -o$out -p${runtimeLockfile.${runtimeVersion}.runner.password}

        # fake runner so igor doesn't crash
        mkdir $out/linux
        touch $out/linux/runner
        7zz a $out/linux/runner.zip $out/linux/runner
        rm $out/linux/runner
      '';

  assets =
    pkgs.runCommand "${projectName}-assets"
      {
        buildInputs = [
          igor

          # igor needs them
          pkgs.zip
          pkgs.unzip
        ];
      }
      ''
        mkdir -p $out

        # we copy the runner to temp because gmac on older versions expects images to be writable
        runtimeCopy=$(mktemp -d)
        # -P because we have symlinks to GMAC and Igor and we don't really need to copy the contents there
        cp -rP ${runtimeFolder}/* $runtimeCopy
        echo ${runtimeFolder}

        chmod -RP a+w $runtimeCopy

        # for the same reason, we copy the source
        srcCopy=$(mktemp -d)
        cp -r ${projectFolder}/* $srcCopy
        chmod -R a+w $srcCopy        

        # igor touches this idk why
        HOME=$(mktemp -d)

        cd $srcCopy
        Igor \
            -j=8 \
            -ac=/cins \
            --project=$srcCopy/${projectName}.yyp \
            --lf=${./guest-license.plist} \
            --rp=$runtimeCopy \
            --temp=$(mktemp -d) \
            --cache=$(mktemp -d) \
            --config=\"${configuration}\" \
            --tf=$out/out.zip \
            linux Package
        unzip $out/out.zip -d $out
        # remove out.zip and the runner extracted by igor
        find $out -maxdepth 1 -type f -delete
      '';

  bareRunner = pkgs.stdenvNoCC.mkDerivation {
    pname = "gm-linux-runner";
    version = runtimeVersion;
    src = runtimeZip;

    nativeBuildInputs = with pkgs; [
      _7zz
      autoPatchelfHook
    ];

    buildInputs = runnerPackages;
    unpackPhase = ''
      mkdir -p $out/bin
      7zz -y x $src linux/runner.zip -o$out -p${runtimeLockfile.${runtimeVersion}.runner.password}
      7zz -y x $out/linux/runner.zip -o$out/bin
      rm -r $out/linux
    '';
    installPhase = ''
      chmod +x $out/bin/runner
    '';
  };
in
pkgs.stdenvNoCC.mkDerivation {
  name = projectName;
  nativeBuildInputs = [
    pkgs.makeWrapper
  ];
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    ln -s ${assets}/assets $out/bin/assets
    cp ${bareRunner}/bin/runner $out/bin/${projectName}

    # ideally this would be done in bareRunner but then it thinks the current directory is at bareRunner 
    # instead of at game and it can't find the assets folder there
    wrapProgram $out/bin/${projectName} \
      --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ pkgs.openal ]}
  '';
  meta = {
    mainProgram = projectName;
  };
}
