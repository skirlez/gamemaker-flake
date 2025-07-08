# gamemaker-flake
A Nix flake for GameMaker, and for playing/compiling GameMaker games.
This flake contains:
- Package outputs for different IDE versions
- A dev shell in the same environment used for the IDE, so you can compile/play games

This flake only targets x86_64-linux for now. If you want to add support for your platform, See 
[Contributing](#contributing)

Please see https://github.com/MichailiK/yoyo-games-runner-nix - without which this flake would have been way worse.

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
### Getting building to work
Go to Preferences > Platform Settings > Ubuntu and set "Steam Runtime SDK Location" to "/".

Explanation: Usually GameMaker runs chroot into a Steam runtime directory, containing many libraries, however the GameMaker environment has all the ones it needs,
so we effectively make the chroot do nothing.

NOTE: YYC does not work as of now.

## Common Issue You May Have Unrelated To Nix I Thought I Should Include
If some of your project files from a Windows project refuse to load, try enabling "Case-Insensitive mode for project files" in Preferences > General Settings

## License
The `debian` folder contains code from https://github.com/MichailiK/yoyo-games-runner-nix, which has no stated license, so
I will not be resolving that ambiguity.

Any other code file is licensed under the AGPLv3 license.

## Contributing
Please contribute