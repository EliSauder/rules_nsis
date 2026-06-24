import json
import sys
import re

#from python.runfiles import Runfiles

#RUNFILES = Runfiles.Create()
#if RUNFILES == None:
#    raise Exception("runfiles is none")

def _parse_status_file(file, current) -> dict:
    result = current
    for line in file:
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(' ', 1)
        if len(parts) == 2:
            result[parts[0]] = parts[1]
        else:
            result[parts[0]] = ""

    return result

def _generate_substitutions(stable, volatile, defaults: str) -> dict:
    result = {}
    if defaults:
        with open(defaults, 'r') as file:
            result = _parse_status_file(file, result)
    if volatile:
        with open(volatile, 'r') as file:
            result = _parse_status_file(file, result)
    if stable:
        with open(stable, 'r') as file:
            result = _parse_status_file(file, result)

    return result


def main(argv):
    if len(argv) < 4:
       raise Exception("Not enough args, needs at least 4")
    if len(argv) > 5:
        raise Exception("To many args, needs at most 5")

    infile = argv[0]
    outfile = argv[1]
    stable_file = argv[2]
    volatile_file = argv[3]
    defaults_file = None
    if len(argv) >= 5:
        defaults_file = argv[4]

    indata = None
    with open(infile, 'r') as file:
        indata = file.read()

    substitutions = _generate_substitutions(stable_file, volatile_file, defaults_file)

    for key, value in substitutions.items():
        indata = indata.replace("{" + key + "}", value)

    indata = re.sub("\\{[A-Z0-9_]+\\}", "", indata)

    with open(outfile, 'w') as file:
        file.write(indata)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
