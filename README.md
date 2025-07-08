# gamemaker-flake
A Nix flake for GameMaker, and for playing/building GameMaker games.
This flake contains:
- Package outputs for different IDE versions
- A shell in the same environment used for the IDE, so you can play/build games

This flake only targets x86_64-linux for now. If you want to add support for your platform, See 
[Contributing](#contributing)

Please see https://github.com/MichailiK/yoyo-games-runner-nix - without which this flake would have been way worse.

## Important
All of the outputs depend on OpenSSL 1.0.2 (for some reason, this library is required to run GameMaker games), which has been EOL since 2019 and is considered insecure.
I couldn't set it up in a way where you explicitly add it to `nixpkgs.config.permittedInsecurePackages` - instead the flake doesn't require you to do anything.
So I'm leaving this warning here. By using any of the outputs you are installing this insecure package.

## Packages
Package output list:
```
Betas:
ide-2023-400-0-324
ide-2024-1400-0-841
ide-latest-beta

Converted:
ide-2023-4-0-84
```
### Converted packages
Packages like `ide-2023-4-0-84` are some Beta version converted using a script to use non-Beta branding (but are otherwise identical).
The use case here is that the version it saves to the `.yyp` is the non-Beta version as well. Use them if you care about that, or if you like the normal branding more.

## Usage
### Adding an IDE package to systemPackages (at least how I do it)
at the very start of the configuration.nix file, add:
```nix
let
  gamemaker-flake = (builtins.getFlake "github:Skirlez/gamemaker-flake");
in
```
or clone the project and add
```nix
let
  gamemaker-flake = (builtins.getFlake "/path/to/gamemaker-flake");
in
```
Then you may pick any of the packages like so:
```nix
environment.systemPackages = with pkgs; [
	...
	gamemaker-flake.packages.x86_64-linux.ide-latest-beta
]
```
### Accessing the GameMaker environment shell
Run:
```
nix develop github:Skirlez/gamemaker-flake
```
or clone the project and run this in its folder:
```
nix develop
```

### Using Stable runtimes
You may have to do this for older versions.

Go to Preferences > Runtime Feeds, and click the Add button.
Fill the left field with whatever you want, and the right field with `https://gms.yoyogames.com/Zeus-Runtime.rss`.
There should now be a new entry under Runtime Feeds for stable runtimes. If you don't see any runtimes inside of it, make sure to press the refresh icon.
If you want, you can also access the LTS runtimes by adding an entry with `https://gms.yoyogames.com/Zeus-Runtime-LTS.rss`

## Common Issue You May Have Unrelated To Nix I Thought I Should Include
If some of your project files from a Windows project refuse to load, try enabling "Case-Insensitive mode for project files" in Preferences > General Settings

## TODO
- I don't think you're meant to package linuxdeploy like that. It'd be great if it used pkgs.appimageTools.wrapType2 like appimagetool, but that doesn't seem to work.
- Add support for YYC

## License
The `debian` folder contains code from https://github.com/MichailiK/yoyo-games-runner-nix, which has no stated license, so
I will not be resolving that ambiguity.

Any other code file is licensed under the AGPLv3 license.

## Contributing
Please contribute