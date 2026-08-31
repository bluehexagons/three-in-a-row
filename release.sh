#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"

fail() {
  printf 'release: %s\n' "$*" >&2
  exit 1
}

if (( $# > 1 )); then
  fail "usage: ./release.sh [major.minor[.patch]]"
fi

command -v git >/dev/null || fail "git is required"
godot_bin="${GODOT_BIN:-godot}"
command -v "$godot_bin" >/dev/null || fail "$godot_bin is required"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail "run this script from the project repository"
[[ -z "$(git status --porcelain)" ]] \
  || fail "the worktree must be clean before preparing a release"

branch="$(git symbolic-ref --quiet --short HEAD)" \
  || fail "releases cannot be created from a detached HEAD"
release_branch="${RELEASE_BRANCH:-main}"
[[ "$branch" == "$release_branch" ]] \
  || fail "switch to $release_branch before preparing a release"

remote="${RELEASE_REMOTE:-origin}"
git remote get-url "$remote" >/dev/null 2>&1 \
  || fail "Git remote '$remote' is not configured"

version_lines="$(grep -c '^config/version="[^"]\+"$' project.godot || true)"
[[ "$version_lines" == "1" ]] \
  || fail "project.godot must contain exactly one application config/version"
current="$(sed -n 's/^config\/version="\([^"]*\)"$/\1/p' project.godot)"
version_pattern='^[0-9]+\.[0-9]+(\.[0-9]+)?$'
[[ "$current" =~ $version_pattern ]] \
  || fail "current project version '$current' is not major.minor[.patch]"

if (( $# == 1 )); then
  next="${1#v}"
else
  IFS='.' read -r -a version_parts <<< "$current"
  last_index=$(( ${#version_parts[@]} - 1 ))
  version_parts[$last_index]=$(( version_parts[$last_index] + 1 ))
  next="$(IFS='.'; printf '%s' "${version_parts[*]}")"
fi

[[ "$next" =~ $version_pattern ]] \
  || fail "next version '$next' is not major.minor[.patch]"
[[ "$next" != "$current" ]] || fail "next version must differ from $current"
highest="$(printf '%s\n%s\n' "$current" "$next" | sort -V | tail -n 1)"
[[ "$highest" == "$next" ]] \
  || fail "next version $next must be newer than $current"

tag="v$next"
git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null \
  && fail "local tag $tag already exists"
if git ls-remote --exit-code --tags "$remote" "refs/tags/$tag" >/dev/null 2>&1; then
  fail "remote tag $tag already exists"
fi

git fetch --quiet "$remote" \
	"+refs/heads/$branch:refs/remotes/$remote/$branch"
remote_branch="$remote/$branch"
git merge-base --is-ancestor "$remote_branch" HEAD \
  || fail "$branch is behind or has diverged from $remote_branch"

release_tmp="$(mktemp -d)"
version_updated=false
release_committed=false
cleanup() {
  status=$?
  rm -rf -- "$release_tmp"
  if (( status != 0 )) && [[ "$version_updated" == true && "$release_committed" == false ]]; then
    git restore --staged --worktree -- project.godot
  fi
  exit "$status"
}
trap cleanup EXIT

sed -i -E "s|^config/version=\"[^\"]+\"$|config/version=\"$next\"|" project.godot
version_updated=true
git diff --check

printf 'Preparing %s (current version: %s)\n' "$tag" "$current"
"$godot_bin" --headless --path . --script tests/test_main.gd
"$godot_bin" --headless --path . --export-release Web "$release_tmp/index.html"
[[ -s "$release_tmp/index.html" ]] || fail "Godot did not produce index.html"

git add project.godot
git commit -m "Release $tag"
release_committed=true
git tag -a "$tag" -m "Release $tag"
git push --atomic "$remote" \
  "refs/heads/$branch:refs/heads/$branch" \
  "refs/tags/$tag:refs/tags/$tag"

printf 'Pushed %s; the tag-only GitHub release workflow should now start.\n' "$tag"
