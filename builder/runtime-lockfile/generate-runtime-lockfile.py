#!/usr/bin/env python3

import io
import os
import sys
import json
import base64
import hashlib
import subprocess
import urllib.request
from dataclasses import dataclass
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

if len(sys.argv) == 1:
	print("Run using the flake's nix run (please)")
	exit(1)

yoyomd5 = sys.argv[1]
	
def download_file_memory(url):
	request = urllib.request.Request(
		url,
		headers = {
			"User-Agent": "balls"
		}
	)
	return urllib.request.urlopen(request)

lockfile = dict()

runner_map = dict()
tools_map = dict()
enclosure_map = dict()

for url in [
			"https://gms.yoyogames.com/Zeus-Runtime.rss",
			"https://gms.yoyogames.com/Zeus-Runtime-LTS2026.rss"
		]:
	with download_file_memory(url) as f:
		tree = ET.parse(f)
		root = tree.getroot()
		
		def fill_map(enclosure, module_name: str, map: dict[str, str]):
			module = next((x for x in enclosure.findall("module") if x.attrib["name"] == module_name), None)
			if module is None:
				return
			url = module.attrib["url"]
			assert url is not None
			map[version] = url
	
		for node in root.findall("channel/item"):
			enclosure = node.find("enclosure")
			if enclosure is None:
				continue
			version_str = node.findtext("title")
			assert version_str is not None
			version = version_str.removeprefix("Version ")
			assert all("name" in x.attrib and "url" in x.attrib for x in enclosure.findall("module"))
			fill_map(enclosure, "linux", runner_map)
			fill_map(enclosure, "base-module-linux-x64", tools_map)
			assert "url" in enclosure.attrib
			enclosure_map[version] = enclosure.attrib["url"]
		
		# as of 03/08/2026 i cannot download these runtimes, it always returns AccessDenied
		missing_runtimes = [
			"2023.6.0.136",
			"2023.8.0.145",
			"2024.4.0.168",
			"2024.4.1.201",
			"2024.6.1.208"
		]
		for x in missing_runtimes:
			_ = tools_map.pop(x, None)
			_ = runner_map.pop(x, None)

def find_password(str):
	# yes this is dumb, but i already wrote this script in python
	code = (f"import {{ yoyomd5 }} from \"{yoyomd5}\"\n"
		f"console.log(btoa(yoyomd5(\"MRJA{str}PHMD\")))")	
	status = subprocess.run(
		["deno", "eval", code],
		text=True,
		stdout=subprocess.PIPE
	)
	assert status.returncode == 0
	return status.stdout[:-1]
@dataclass
class Entry:
	tools_url: str
	runner_url: str
	enclosure_url: str

combined = dict()
for x in tools_map:
	if x in runner_map and x in enclosure_map:
		combined[x] = Entry(tools_map[x], runner_map[x], enclosure_map[x])
	
fail = False
def hash_zip_file(version_and_entry):
	version = version_and_entry[0]
	entry: Entry = version_and_entry[1]
	try:
		with download_file_memory(entry.tools_url) as response:
			tools_sha = hashlib.sha256(response.read()).hexdigest()

		tools_pw = find_password(entry.tools_url.rsplit("/")[-1])

		with download_file_memory(entry.runner_url) as response:
			runner_sha = hashlib.sha256(response.read()).hexdigest()
		runner_pw = find_password(entry.runner_url.rsplit("/")[-1])

		with download_file_memory(entry.enclosure_url) as response:
			enclosure_sha = hashlib.sha256(response.read()).hexdigest()
		enclosure_pw = find_password(entry.enclosure_url.rsplit("/")[-1])

		print(f"Results for v{version}:\n"
			f"Tools sha256: {tools_sha}\nBase password: {tools_pw}\n"
			f"Runner sha256: {runner_sha}\nRuntime password: {runner_pw}\n"
			f"Enclosure sha256: {enclosure_sha}\nEnclosure password: {enclosure_pw}\n"
		)

		lockfile[version] = { 
			"tools": { "url": entry.tools_url, "sha256": tools_sha, "password" : tools_pw }, 
			"runner": { "url": entry.runner_url, "sha256": runner_sha, "password" : runner_pw }, 
			"enclosure": { "url": entry.enclosure_url, "sha256": enclosure_sha, "password" : enclosure_pw }, 
		}
	except Exception as e:
		print(f"Error occured for {version}. Exception string:\n{str(e)}")
		global fail
		fail = True
with ThreadPoolExecutor(max_workers=6) as exe:
	exe.map(hash_zip_file, combined.items())
if fail:
	print("Some download failed, not writing")
	exit(1)
with open("../runtimes.lock", "w") as f:
	json.dump(lockfile, f, sort_keys=True, indent=4)
print("Written to runtimes.lock")
