{
  projectFolder,
  projectName,
  pkgs,
}:
let
  fixed-yyp =
    pkgs.runCommand "${projectName}-fixed-yyp"
      {
        nativeBuildInputs = [
          pkgs.yaml2json
        ];
      }
      ''
        yaml2json < ${projectFolder}/${projectName}.yyp > $out
      '';
in
fixed-yyp
