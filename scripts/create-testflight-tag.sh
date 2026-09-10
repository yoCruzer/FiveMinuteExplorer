#!/bin/bash
set -euo pipefail
[[ $# == 2 || ( $# == 3 && $3 == --push ) ]] || {
  echo 'Usage: create-testflight-tag.sh VERSION BUILD [--push]' >&2; exit 2;
}
cd "$(dirname "$0")/.."
scripts/release-preflight.sh "$1" "$2"
tag="testflight-$1-build$2"
head=$(git rev-parse HEAD)
if [[ ${3:-} != --push ]]; then
  echo "DRY RUN: would create and push $tag at $head. Nothing changed."
  exit 0
fi
[[ $(git branch --show-current) == main && -z $(git status --porcelain) \
   && $head == "$(git rev-parse origin/main)" ]] || { echo 'Main changed after preflight' >&2; exit 1; }
git tag -a "$tag" "$head" -m "TestFlight $1 ($2)"
if ! git push origin "refs/tags/$tag:refs/tags/$tag"; then
  echo "Push failed or outcome uncertain. Local tag $tag remains at $head." >&2
  echo "Inspect: git ls-remote --tags origin 'refs/tags/$tag*'" >&2
  echo "Do not overwrite a remote tag. If confirmed absent, retry only this tag or remove the local tag deliberately." >&2
  exit 1
fi
echo "Pushed only $tag at $head. Xcode Cloud owns signing/distribution."
