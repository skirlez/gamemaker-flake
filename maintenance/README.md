
## Maintenance

Developer script(s) for updating the flake.

Update runtimes and latest beta IDE:
```bash
nix run
```

Verify that all the runtime downloads still work:
```bash
nix run .#verify
```

### Runtimes


generate-lockfile.py parses the following rss files:
```
https://gms.yoyogames.com/Zeus-Runtime.rss
https://gms.yoyogames.com/Zeus-Runtime-LTS.rss
https://gms.yoyogames.com/Zeus-Runtime-LTS2026.rss
https://gms.yoyogames.com/Zeus-Runtime-NuBeta.rss
```
Which contain all the GameMaker runtimes, and:
```
"https://gms.yoyogames.com/update-linux-NuBeta.rss",
"https://gms.yoyogames.com/update-linux-LTS2026.rss"
```
Which contain all the GameMaker IDEs.

It downloads every zip for every runtime it can to find the hash in order to generate runtimes.lock, and it downloads the latest IDE versions for ides.lock.

While writing the script it occurred to me that the zips were password protected. Fortunately the method of obtaining the passwords seems to have been known for years. This script uses the MIT licensed https://github.com/jakeayy/Yoyo-MD5 to find the passwords. Yes it does so by calling deno with subprocess, and by having the minified JS be a non-flake input that is passed into the python script when you do `nix run`. Yes it's dumb I don't want to rewrite the script.

Anyway, because of that, I have copied the MIT license from that repo to this folder. I think they forgot to update the "copyright" part.

However, the flake and the script itself both still follow the license of gamemaker-flake, which is AGPLv3.
