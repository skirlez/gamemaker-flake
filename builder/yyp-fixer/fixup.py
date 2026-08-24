import os
import sys

def strip_trailing_commas(str: str):
	build = list()
	in_string = False
	last_seen_comma = -1
	for i in range(len(str) - 1):
		if not in_string:
			if str[i] == '"':
				build += '"'
				in_string = True
			else:
				build += str[i]
				if str[i] == ',':
					last_seen_comma = len(build) - 1
				if last_seen_comma != -1 and (str[i + 1] == ']' or str[i + 1] == '}'):
					found = False
					for j in range(last_seen_comma + 1, len(build) - 1):
						if not build[j].isspace():
							found = True
							break
					if not found:
						build[last_seen_comma] = ' ';
						last_seen_comma = -1
		else:
			# inside a string
			build += str[i]
			if str[i] == '"':
				in_string = False
	build += str[len(str) - 1]
	return ''.join(build)

with open(sys.argv[1]) as f:
	fixed = strip_trailing_commas(f.read())
with open(sys.argv[2], "w") as f:
	f.write(fixed)
