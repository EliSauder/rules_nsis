#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

download_plugin() {
    local filename=$1
    local sourceforge_path=$2
    local sha256=$3
    local mirror="https://github.com/EliSauder/rules_nsis/releases/download/v0.1.0"

    if ! curl --fail --location --retry 3 --output "$filename" "$mirror/$filename"; then
        echo "GitHub mirror unavailable for $filename; downloading from SourceForge." >&2
        curl --fail --location --retry 3 --output "$filename" \
            "https://nsis.sourceforge.io/mediawiki/images/$sourceforge_path/$filename"
    fi
    echo "$sha256  $filename" | sha256sum --check
}

download_plugin NsArray.zip 9/97 \
    56cef303f97de3a6e26ccfe9a8a860bbb539a08c520d312e7774cce310013723
download_plugin EnVar_plugin.zip 7/7f \
    e9aa92de351345ed82795251d838f1ae9041ba35af9d381a5780c7843b01f56a
