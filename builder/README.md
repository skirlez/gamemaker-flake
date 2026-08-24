# Project builder

The project builder output is available in `packages.x86_64-linux.buildGameMakerProject`.

This builder builds GameMaker projects by packaging and utilizing official GameMaker tooling
(Igor, GMAC) plus the runner itself, downloading them directly from YoYoGames.
The build procedure it performs is very similar to what the IDE does.

Therefore, this serves a different purpose to https://github.com/MichailiK/yoyo-games-runner-nix.
Unlike that project, you cannot use this builder to package closed-source games.

## Required attributes

### `src`

The folder containing the GameMaker project.

## Optional attributes

### `runtimeVersion`

Runtime version to use. 

If unspecified, the builder will try choose a runtime version based off of the runtime version in the .yyp file.
You can check which version is picked with `--traceVerbose`.

The builder can fail to choose a version, and in this case you must supply this attribute. For valid runtime versions, please see [runtimes.lock](https://github.com/skirlez/gamemaker-flake/tree/main/builder/runtimes.lock). It's most of them!

### `configuration`

Which configuration to build. Set to `"Default"` by default.

## Errors

This section contains common errors you might encounter with the builder. If you find something not listed here, open an issue!

### Prefab error

If the build fails with an error message regarding prefabs, look at `ForcedPrefabProjectReferences` inside your project's .yyp file.
Create a folder called `prefabs` in the project folder. You must copy every prefab referenced in `ForcedPrefabProjectReferences` to there.
You can copy them from your IDE's prefabs cache at `~/.local/share/GameMakerStudio2(-SUFFIX)/Prefabs`
(-SUFFIX might be -Beta or -LTS2026, for example).

Theoretically, these could be fetched at build time if we can get exact versions of each project references.
This would be coupled together with a new parameter like `prefabsHash`.

### Casing

The asset compiler, specifically older versions, seem to struggle in case-sensitive environments.

Newer versions have a case-insensitive flag you can set, but I'm pretty sure it doesn't fix everything in the following text.

The problem seems to arise when making projects using the Windows IDE (As that platform is case-insensitive). That version of the IDE can make some strange combinations
of:

- The asset name in the .yyp
- The path to the asset in the .yyp
- The asset folder name
- The name of the asset's .yy file
- The name mentioned inside the asset's .yy file

Opening these up in an Ubuntu IDE can cause even more issues, and leave several versions of the same asset with different casing!

I considered a systemic solution at first using a Python script which passes through a project, but found just going through my personal projects how deep such a solution would need to go, and I'm not even getting paid for this.
Hire me, YoYo Games

Basically, you need to normalize your asset name cases on your own. How exactly, depends on your project, and the exact runtime version. It sucks, good luck.

## No GameMaker license required? How?

There is a guest license in this repository. If it stops working due to expiration, I am fairly confident you could lie to the compiler about the current date.
Testing old, expired licenses of mine, they seem to keep working on all versions I've tested.

Note that we can't pull the guest license at build time, that would not be reproducible.
