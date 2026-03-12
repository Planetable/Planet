#!/bin/sh

set -eu

repo_root=$(git rev-parse --show-toplevel)
git_dir=$(git rev-parse --git-dir)
case "$git_dir" in
    /*) ;;
    *) git_dir="$repo_root/$git_dir" ;;
esac

actual_index="$git_dir/index"
current_index="${GIT_INDEX_FILE:-$actual_index}"
version_file="Planet/versioning.xcconfig"
build_number=$(( $(git rev-list --count HEAD) + 1 ))
version_line="CURRENT_PROJECT_VERSION = $build_number"

cd "$repo_root"

current_line=""
if [ -f "$version_file" ]; then
    current_line=$(cat "$version_file")
fi

if [ "$current_line" != "$version_line" ]; then
    printf '%s\n' "$version_line" > "$version_file"
    printf 'Set CURRENT_PROJECT_VERSION to %s\n' "$build_number"
    git add -- "$version_file"

    # Partial commits can run hooks against a temporary index.
    if [ "$current_index" != "$actual_index" ]; then
        GIT_INDEX_FILE="$actual_index" git add -- "$version_file"
    fi
fi
