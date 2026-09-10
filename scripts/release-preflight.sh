#!/bin/bash
set -euo pipefail
fail() { echo "Preflight blocked: $*" >&2; exit 1; }
[[ $# == 2 ]] || fail 'Usage: release-preflight.sh VERSION BUILD'
version=$1
build=$2
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $build =~ ^[1-9][0-9]*$ ]] || fail 'Invalid version/build'
cd "$(dirname "$0")/.."
[[ $(git branch --show-current) == main ]] || fail 'Must run on merged main after independent review'
[[ -z $(git status --porcelain) ]] || fail 'Worktree must be clean'
command -v gh >/dev/null || fail 'GitHub CLI is required'
gh auth status >/dev/null 2>&1 || fail 'Run gh auth login first'
git fetch origin main --tags
head=$(git rev-parse HEAD)
[[ $head == "$(git rev-parse refs/remotes/origin/main)" ]] || fail 'HEAD differs from origin/main'
python3 scripts/verify-static.py
python3 - "$version" "$build" <<'PY'
import sys
sys.path.insert(0, 'scripts')
import importlib.util
spec = importlib.util.spec_from_file_location('verify_static', 'scripts/verify-static.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
if any(s['MARKETING_VERSION'] != sys.argv[1] or s['CURRENT_PROJECT_VERSION'] != sys.argv[2]
       for s in module.app_settings()):
    sys.exit('Preflight blocked: supplied version/build differs from project')
PY
tag="testflight-$version-build$build"
if git show-ref --verify --quiet "refs/tags/$tag"; then fail "Local tag already exists: $tag"; fi
remote_tag=$(git ls-remote --tags origin "refs/tags/$tag")
[[ -z $remote_tag ]] || fail "Remote tag already exists: $tag"
for workflow in ios-ci.yml ios-full-qa.yml; do
  event=push
  [[ $workflow != ios-full-qa.yml ]] || event=workflow_dispatch
  runs=$(gh run list --workflow "$workflow" --branch main --commit "$head" --event "$event" \
    --status success --limit 100 --json databaseId,headSha,headBranch,event,status,conclusion)
  run_id=$(python3 -c '
import json, sys
runs = json.load(sys.stdin)
matches = [r for r in runs if r["headSha"] == sys.argv[1] and r["headBranch"] == "main"
           and r["event"] == sys.argv[2] and r["status"] == "completed" and r["conclusion"] == "success"]
if not matches: sys.exit("Preflight blocked: no exact-main-HEAD successful " + sys.argv[3])
print(matches[0]["databaseId"])
' "$head" "$event" "$workflow" <<< "$runs")
  evidence=$(gh run view "$run_id" --json headSha,headBranch,event,status,conclusion,jobs,url)
  python3 -c '
import json, sys
r = json.load(sys.stdin)
required = {"static", "ios"} if sys.argv[3] == "ios-ci.yml" else {"full-qa"}
jobs = {j["name"]: j for j in r["jobs"]}
if not (r["headSha"] == sys.argv[1] and r["headBranch"] == "main" and r["event"] == sys.argv[2]
        and r["status"] == "completed" and r["conclusion"] == "success"
        and all(n in jobs and jobs[n]["conclusion"] == "success" for n in required)):
    sys.exit("Preflight blocked: workflow/job evidence does not satisfy release gate")
print("Verified " + sys.argv[3] + ": " + r["url"])
' "$head" "$event" "$workflow" <<< "$evidence"
done
echo "PASS: $tag at exact main HEAD $head; no tag created"
