generate-runtime-lockfile.py parses the rss available from https://gms.yoyogames.com/Zeus-Runtime.rss used for gamemaker runtimes.
It downloads every zip for every (valid (it's complicated)) runtime to find the hash in order to generate runtime.lock.
There should probably be a way to update the lock instead of redownloading all the runtimes every time a new one comes out... maybe

While writing the script it occurred to me that the zips were password protected. Fortunately the method of obtaining the passwords seems to have been known for years. This script uses the MIT licensed https://github.com/jakeayy/Yoyo-MD5 to find the passwords. Yes it does so by calling deno with subprocess, and by having the minified JS be a non-flake input that is passed into the python script when you do `nix run`. Yes it's dumb I don't want to rewrite the script. But that's why you should use `nix run` to run the script.

Anyway, because of that, I have copied the MIT license to this folder.

However, the flake and the script itself both still follow the license of gamemaker-flake, which is AGPLv3.
