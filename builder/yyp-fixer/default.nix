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
          pkgs.python3
        ];
      }
      ''
        python3 ${./fixup.py} ${projectFolder}/${projectName}.yyp $out
      '';
in
fixed-yyp
