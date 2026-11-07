#!/bin/bash
set -euo pipefail
# Refuse an older SDK or a silent switch to Xcode 27. Override by changing this script deliberately.
XCODE_PATH="$(python3 - <<'PYCODE'
import glob,re
paths=glob.glob('/Applications/Xcode_26*.app/Contents/Developer')
if not paths: raise SystemExit('Xcode 26 not installed on this runner; inspect runner-images documentation.')
def version(p): return tuple(map(int,re.search(r'Xcode_([\d.]+)',p)[1].strip('.').split('.')))
print(max(paths,key=version))
PYCODE
)"
sudo xcode-select -s "$XCODE_PATH"
xcodebuild -version
xcodebuild -showsdks
