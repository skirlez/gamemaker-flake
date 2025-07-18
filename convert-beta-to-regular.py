import os
import sys

beta_version = sys.argv[1]
version = sys.argv[2]
top_directory = sys.argv[3]

def version_to_bytes(version):
    arr = version.split(".")
    result = bytearray(8)
    index = 0
    for number in arr:
        number = int(number)
        result[index] = number % 256
        result[index + 1] = number // 256
        index += 2
    return bytes(result)

def process(file_path, padding):
    global beta_version
    global version

    beta_version_string_bytes = beta_version.encode('ascii')
    version_string_bytes = version.encode('ascii')
    if padding:
        version_string_bytes += b"\x00" * (len(beta_version) - len(version))

    beta_version_bytes = version_to_bytes(beta_version)
    version_bytes = version_to_bytes(version)
    
    with open(file_path, 'rb') as f:
        content = f.read()
    write = False
    if beta_version_string_bytes in content:
        content = content.replace(beta_version_string_bytes, version_string_bytes)
        #print("found string version bytes in " + file_path)
        write = True
    if beta_version_bytes in content:
        content = content.replace(beta_version_bytes, version_bytes)
        #print("found version bytes " + file_path)
        write = True
    
    if write:
        with open(file_path, 'wb') as f:
            f.write(content)

def walk_and_replace(top_dir):
    for dirpath, _, filenames in os.walk(top_dir):
        for filename in filenames:
            if filename.lower().endswith('.dll') or filename.lower().endswith('.deps.json'):
                full_path = os.path.join(dirpath, filename)
                process(full_path, filename.lower().endswith('.dll'))

walk_and_replace(top_directory)
        