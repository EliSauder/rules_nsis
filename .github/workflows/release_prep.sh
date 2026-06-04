#!/usr/bin/env bash
set -o nounset
set -o pipefail
set -o errexit

set -x

CUR_TAG=$1
if [ -z "$CUR_TAG" ]; then
    echo "Tag must be set"
    exit 1
fi

git checkout "$CUR_TAG"

RELNAME="rules_nsis-$CUR_TAG"
ARCHIVE="$RELNAME.tar.gz"

git archive --format=tar "--prefix=$RELNAME/" "$CUR_TAG" | gzip > "$ARCHIVE"

docs="$(mktemp -d)"
targets="$(mktemp)"
bazel --output_base="$docs" query --output=label --output_file="$targets" \
    'kind("starlark_doc_extract rule", //...)'
bazel --output_base="$docs" build --target_pattern_file="$targets"

tar --create --auto-compress \
    --directory "$(bazel --output_base="$docs" info bazel-bin)" \
    --file "$GITHUB_WORKSPACE/${ARCHIVE%.tar.gz}.docs.tar.gz" .
