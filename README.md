# gamemaker-flake
A Nix flake for GameMaker, and for playing/building GameMaker games.
This flake has:
- Package outputs for different IDE versions
- A shell in the same environment used for the IDE, so you can play/build games
- Support for VM/YYC building, with no setup required!

This flake only targets x86_64-linux for now. If you want to add support for your platform, See 
[Contributing](#contributing)

Please see https://github.com/MichailiK/yoyo-games-runner-nix - without which this flake would have been way worse.

## Important
- All of the outputs depend on OpenSSL 1.0.2 (for some reason, this library is required to run GameMaker games), which has been EOL since 2019 and is considered insecure.
I couldn't set it up in a way where you explicitly add it to `nixpkgs.config.permittedInsecurePackages` - instead the flake doesn't require you to do anything.
So I'm leaving this warning here. By using any of the outputs you are installing this insecure package.

- All old packages pull from https://github.com/Skirlez/gamemaker-ubuntu-archive as GameMaker removed all of their old releases a while back.
(If you have any `.deb` files of old releases, please open an issue there!)
## Packages
Package output list:
```
Betas:
ide-latest-beta
ide-2024-1400-0-849
ide-2023-400-0-324

Internal-Normal:
ide-latest
ide-2024-13-0-190
ide-2023-11-1-129
ide-2023-8-2-108
ide-2023-4-0-84

Converted:
None
```
### Internal-Normal packages
GameMaker does not actually have non-Beta versions for their Ubuntu IDE, but these builds without Beta branding exist or used to exist on their servers.
It should be noted you're putting your project in the exact same risk as using a Beta IDE version, by using these versions. Always use source control!

I happened to have more of these downloaded and archived than normal Betas.

### Converted packages
For versions without an Internal-Normal build archived, there is a conversion script in this repository (`convert-beta-to-regular.py`). They still differ from those builds,
most importantly the folders it uses for configurations are named `GameMakerStudio2-Beta` instead of `GameMakerStudio2`.
The use case here is that the version it saves to the `.yyp` is the non-Beta version as well. Use them if you care about that, or if you like the normal branding more.

...

(There currently aren't any versions that are missing an equivalent Internal-Normal build...)

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

### Using non-Beta runtimes with Beta IDE versions
You may have to do this for older versions.

Go to Preferences > Runtime Feeds, and click the Add button.
Fill the left field with whatever you want, and the right field with `https://gms.yoyogames.com/Zeus-Runtime.rss`.
There should now be a new entry under Runtime Feeds for stable runtimes. If you don't see any runtimes inside of it, make sure to press the refresh icon.
If you want, you can also access the LTS runtimes by adding an entry with `https://gms.yoyogames.com/Zeus-Runtime-LTS.rss`

## HELP!!!
- If some of your project files from a Windows project refuse to load, try enabling "Case-Insensitive mode for project files" in Preferences > General Settings
- If the font for code sucks ass, you can switch it in Preferences > Text Editors > Code Editor > Colours > Default. I believe "Droid Sans Mono" is the default font from the Windows version but I don't remember. 
- If you can't see any of your system fonts, try enabling `fonts.fontDir.enable`.

## TODO
- I don't think you're meant to package linuxdeploy like that. It'd be great if it used pkgs.appimageTools.wrapType2 like appimagetool, but that doesn't seem to work.
- Make YYC use clang 3.8 and not clang 12. In general, clean up the way YYC compilation works.
- Actually, clean up the entire thing. 
- The online manual doesn't work (middle-clicking any function just takes you to the start page). Switching to the offline manual and downloading it when prompted does, though.
- Audio playback in the IDE has crackles, for any file imported from a non .wav format
- The IDE cannot kill the currently running game process when pressing stop/play/debug
- GMRT (I just don't use it, so I haven't looked into it, but I want to get it working)


## License
The `debian` folder contains code from https://github.com/MichailiK/yoyo-games-runner-nix, which has no stated license, so
I will not be resolving that ambiguity.

Any other code file is licensed under the AGPLv3 license.

## Contributing
Please contribute