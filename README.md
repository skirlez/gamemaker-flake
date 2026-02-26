# gamemaker-flake
A Nix flake for GameMaker, and for playing/building GameMaker games.
This flake has:
- Package outputs for different IDE versions
- A shell in the same environment used for the IDE, so you can run games
- A more lightweight shell that can run Igor for building from the terminal
- Support for VM/YYC building, with no setup required!

This flake only targets `x86_64-linux` for now. If you want to add support for your platform, See 
[Contributing](#contributing)

Please see https://github.com/MichailiK/yoyo-games-runner-nix - without which this flake would have been way worse.

## Important
- All of the outputs depend on OpenSSL 1.0.2 (for some reason, this library is required to run GameMaker games), which has been EOL since 2019 and is considered insecure.
I couldn't set it up in a way where you explicitly add it to `nixpkgs.config.permittedInsecurePackages` - instead the flake doesn't require you to do anything.
So I'm leaving this warning here. By using any of the outputs you are installing this insecure package.

- All old packages pull from https://github.com/skirlez/gamemaker-ubuntu-archive as GameMaker removed all of their old releases a while back.
(If you have any `.deb` files of old releases, please open an issue there!)

- In the event the `.deb` for a version is removed from GameMaker's servers, it will be uploaded to the archive and this flake will be updated to pull that version from there.

## Packages
Package output list:
```
Betas:
ide-latest-beta
ide-2024-1400-4-1003
ide-2023-400-0-324

Internal-Normal:
ide-latest
ide-2024-13-1-193
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

(There currently aren't any versions that are missing an equivalent Internal-Normal build... so there are no converted packages as of now...)

## Usage
### Adding an IDE package to systemPackages (at least how I do it)
at the very start of the configuration.nix file, add:
```nix
let
  gamemaker-flake = (builtins.getFlake "github:skirlez/gamemaker-flake");
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
nix develop github:skirlez/gamemaker-flake
```
or clone the project and run this in its folder:
```
nix develop
```

### Accessing the Igor environment shell
Run:
```
nix develop github:skirlez/gamemaker-flake#igor
```
or clone the project and run this in its folder:
```
nix develop .#igor
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
- If you can't see any of your system fonts and you're on NixOS, try enabling `fonts.fontDir.enable`.

## Technical Details

GameMaker requires the [Steam Runtime 1 'scout' SDK](https://gitlab.steamos.cloud/steamrt/scout/sdk) to run games. The Steam runtime is basically a collection of libraries and utilities packaged in an FHS file structure (so it has a `/bin`, `/usr`, `/lib`, and so on).
During compilation, GameMaker will invoke `chroot` to change the current root directory to the Steam runtime folder and perform the building process there, so it happens in a predictable environment (as doing that avoids relying on any libraries and utilities from your system, so it should be the same for everyone).

I wanted to avoid having the packages download the entire Steam runtime, so instead, the packages have GameMaker run in its own FHS environment (using `pkgs.buildFHSEnv`) and they fetch and build just the libraries and utilities that are needed (which is much cleaner).

To avoid the `chroot`, in the FHS environment `/opt/steam-runtime` (the default directory GameMaker expects the Steam runtime to be in) is symlinked to `/`, making the `chroot` do nothing, and so GameMaker will perform the building in our FHS environment instead.

You can still download and specify the Steam runtime location manually in Preferences > Platform Settings > Ubuntu, and everything will still work.
If you want to do that, the latest image (which GameMaker links in their [guide](https://github.com/YoYoGames/GameMaker-Bugs/wiki/Ubuntu-GMS2)) is available [here](https://repo.steampowered.com/steamrt-images-scout/snapshots/latest-steam-client-general-availability/com.valvesoftware.SteamRuntime.Sdk-amd64,i386-scout-sysroot.tar.gz).

## TODO
- Have all packages reuse the same FHS environment. If that's not possible/unideal, there are a few libraries only needed for some versions but not others, and those should only be included when necessary
- The online manual doesn't work (middle-clicking any function just takes you to the start page). Switching to the offline manual and downloading it when prompted does, though.
- Audio playback in the IDE has crackles, for any file imported from a non .wav format
- The IDE cannot kill the currently running game process when pressing stop/play/debug
- Have runtimes be managed by the flake
(Should be possible, would be cool. I imagine each IDE package would by default include the runtime package for Ubuntu matching that version, and you could override it with whatever you want)
- GMRT support (As in, without setup. Maybe it could be made into a Nix derivation if how the GameMaker Package Manager downloads it is understood) (I have no idea if it's possible to run GMRT the intended way with this flake. I tried for a bit but it seemed to not be Fun)


## License
This flake is licensed under the AGPLv3 license.

For the purpose of contributing to [Nixpkgs](https://github.com/NixOS/nixpkgs), you may use this code however you see fit, without attribution.
I would submit a GameMaker package myself, but the process seems annoying, and I doubt the package outputs here are written in a sufficiently correct way.

## Contributing
Please contribute
