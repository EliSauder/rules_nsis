import json
import os
import sys

def _resolve_signed_directory(component: dict, signed_dir: str) -> None:
    """Adds one Files entry per file actually found inside `signed_dir`.

    `signed_dir` is a Bazel directory artifact populated by a signing action
    (see `_sign_component_files` in defs.bzl) that has already run by the
    time this action executes, so its real contents - including any sidecar
    files a signing tool appends to a name (e.g. cosign's detached
    ".sig"/".bundle.json") - are only knowable now, not when the rule's
    Starlark analyzed the target. Listing them here, rather than predicting
    names in the rule, means the installer only ever references (and later
    removes) files the signer actually produced.
    """
    files = component.setdefault("Files", [])
    for name in sorted(os.listdir(signed_dir)):
        files.append({
            "Name": name,
            "Source": os.path.join(signed_dir, name),
        })

def _walk(node, manifest: dict) -> None:
    """Recursively visits every dict/list in `node`, resolving any component
    dict whose "Name" matches an entry in `manifest` (a name -> signed
    directory path mapping).

    A generic walk is used, rather than assuming a fixed shape, because
    component data shows up in more than one place in the rendered
    datasources with different nesting - inline under the installer's
    `Components`/`ComponentGroups` (used by the main install/uninstall
    sections), and as the top-level dict of each component's own
    `component_<name>` datasource (used by user pre/post-install hooks).
    """
    if isinstance(node, dict):
        name = node.get("Name")
        if name in manifest:
            _resolve_signed_directory(node, manifest[name])
        for value in node.values():
            _walk(value, manifest)
    elif isinstance(node, list):
        for item in node:
            _walk(item, manifest)

def main(argv):
    if len(argv) != 3:
        raise Exception("Expected exactly 3 args: infile, outfile, manifest")

    infile, outfile, manifest_file = argv

    with open(infile, 'r') as file:
        data = json.load(file)

    with open(manifest_file, 'r') as file:
        manifest = json.load(file)

    _walk(data, manifest)

    with open(outfile, 'w') as file:
        json.dump(data, file)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
