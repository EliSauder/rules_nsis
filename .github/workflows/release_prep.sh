#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

TAG=$1

PREFIX="rules_nsis-${TAG:1}"
ARCHIVE="rules_nsis-$TAG.tar.gz"
ARCHIVE_TMP=$(mktemp -d)
trap 'rm -r -- "$ARCHIVE_TMP"' EXIT

git archive --format=tar "--prefix=$PREFIX/" "$TAG" | tar --extract --directory="$ARCHIVE_TMP"
sed -i "s|^_PLUGIN_RELEASE_TAG = .*|_PLUGIN_RELEASE_TAG = \"$TAG\"|" \
    "$ARCHIVE_TMP/$PREFIX/MODULE.bazel"

tar --create --gzip --directory="$ARCHIVE_TMP" --file="$ARCHIVE" "$PREFIX"

bash .github/workflows/release_plugins.sh "$TAG" >&2

# Add generated API docs to the release, see https://github.com/bazelbuild/bazel-central-registry/issues/5593
docs="$(mktemp -d)"; targets="$(mktemp)"
bazel --output_base="$docs" query --output=label --output_file="$targets" 'kind("starlark_doc_extract rule", //...)'
bazel --output_base="$docs" build --target_pattern_file="$targets"
tar --create --auto-compress \
    --directory "$(bazel --output_base="$docs" info bazel-bin)" \
    --file "$GITHUB_WORKSPACE/${ARCHIVE%.tar.gz}.docs.tar.gz" .
