#!/bin/bash
set -euo pipefail
[[ $# == 0 || ( $# == 1 && $1 == --full-qa ) ]] || { echo 'Usage: ci-ios.sh [--full-qa]' >&2; exit 2; }
full_qa=${1:-}
cd "$(dirname "$0")/.."
mkdir -p "${CI_ARTIFACT_DIR:-.ci-artifacts}"
artifact_root=$(cd "${CI_ARTIFACT_DIR:-.ci-artifacts}" && pwd)
run_dir=$(mktemp -d "$artifact_root/run.XXXXXX")
echo "Artifacts: $run_dir"
uname -sm
sw_vers
xcodebuild -version
xcrun simctl list devices available -j > "$run_dir/devices.json"
simulator=$(python3 - "$run_dir/devices.json" <<'PY'
import json, re, sys
from pathlib import Path
project = Path('FiveMinuteExplorer.xcodeproj/project.pbxproj').read_text()
minimum = max(tuple(map(int, v.split('.'))) for v in re.findall(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);', project))
choices = []
for runtime, devices in json.load(open(sys.argv[1]))['devices'].items():
    match = re.search(r'\.iOS-([\d-]+)$', runtime)
    if not match:
        continue
    version = tuple(map(int, match[1].split('-')))
    if version < minimum:
        continue
    for device in devices:
        if device['isAvailable'] and device['name'].startswith('iPhone'):
            choices.append((version, device['state'] == 'Booted', device['name'], device['udid']))
if not choices:
    sys.exit(f'No available iPhone simulator compatible with deployment target {minimum}')
version, _, name, udid = sorted(choices, reverse=True)[0]
print(f'Simulator: {name}, iOS {".".join(map(str, version))}, {udid}', file=sys.stderr)
print(udid)
PY
)
destination="platform=iOS Simulator,id=$simulator"
common=(-project FiveMinuteExplorer.xcodeproj -scheme FiveMinuteExplorer CODE_SIGNING_ALLOWED=NO)
xcodebuild "${common[@]}" test -configuration Debug -destination "$destination" \
  -parallel-testing-enabled NO -only-testing:FiveMinuteExplorerTests \
  -derivedDataPath "$run_dir/DerivedData-tests" -resultBundlePath "$run_dir/unit.xcresult" \
  2>&1 | tee "$run_dir/unit.log"
xcodebuild "${common[@]}" build -configuration Debug -destination "$destination" \
  -derivedDataPath "$run_dir/DerivedData-debug" 2>&1 | tee "$run_dir/debug.log"
xcodebuild "${common[@]}" build -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$run_dir/DerivedData-release" 2>&1 | tee "$run_dir/release.log"
if [[ $full_qa == --full-qa ]]; then
  xcodebuild "${common[@]}" test -configuration Debug -destination "$destination" \
    -parallel-testing-enabled NO \
    -only-testing:FiveMinuteExplorerUITests/FiveMinuteExplorerUITests/testStabilizationLargeTextFlow \
    -derivedDataPath "$run_dir/DerivedData-ui" -resultBundlePath "$run_dir/ui.xcresult" \
    2>&1 | tee "$run_dir/ui.log"
fi
echo 'PASS: focused tests, fresh Debug Simulator, unsigned generic Release'
