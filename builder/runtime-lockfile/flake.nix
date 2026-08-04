{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.yoyomd5 = {
    url = "https://raw.githubusercontent.com/jakeayy/Yoyo-MD5/df87410f09ea91637be02ec29f9fb312065d441c/js/md5.min.js";
    flake = false;
  };
  outputs =
    {
      self,
      nixpkgs,
      yoyomd5,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.x86_64-linux.default = pkgs.writeShellApplication {
        name = "update-runtimes-lockfile";
        runtimeInputs = with pkgs; [
          python3
          deno
        ];
        text = ''
          	python3 ./generate-runtime-lockfile.py ${yoyomd5}
        '';
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };

}
