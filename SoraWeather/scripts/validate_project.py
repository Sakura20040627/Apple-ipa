#!/usr/bin/env python3
"""Dependency-free structure checks. Does not substitute for xcodebuild or XCTest."""
import ast, json, pathlib, plistlib, re, subprocess, sys, xml.etree.ElementTree as ET
root=pathlib.Path(__file__).resolve().parents[1]
pbx=(root/'SoraWeather.xcodeproj/project.pbxproj').read_text()
ids=re.findall(r'^([A-F0-9]{24}) =',pbx,re.M)
assert len(ids)==len(set(ids))
for ref in re.findall(r'\b[A-F0-9]{24}\b',pbx): assert ref in ids, 'Unresolved object '+ref
for path in re.findall(r'path = "([^"]+)";',pbx): assert (root/path).exists(), 'Missing project file '+path
for f in list((root/'App').glob('*.swift'))+list((root/'Core').glob('*.swift')): assert str(f.relative_to(root)) in pbx, 'Uncompiled source '+str(f)
info=plistlib.loads((root/'Resources/Info.plist').read_bytes())
assert info['BGTaskSchedulerPermittedIdentifiers']==['app.sora.weather.refresh']
assert info['UIBackgroundModes']==['fetch']
assert 'NSLocationAlwaysAndWhenInUseUsageDescription' not in info
assert 'NSAppTransportSecurity' not in info
privacy=plistlib.loads((root/'Resources/PrivacyInfo.xcprivacy').read_bytes())
assert not privacy['NSPrivacyTracking']
ET.parse(root/'SoraWeather.xcodeproj/xcshareddata/xcschemes/SoraWeather.xcscheme')
for f in root.glob('scripts/*.py'): ast.parse(f.read_text())
for f in root.glob('scripts/*.sh'): subprocess.run(['bash','-n',str(f)],check=True)
for f in root.glob('Tests/Fixtures/*.json'): json.loads(f.read_text())
assert 'iphonesimulator' in (root/'scripts/simulator_smoke.sh').read_text()
workflow=(root/'.github/workflows/ios.yml').read_text()
assert 'swift test' in workflow and 'CODE_SIGNING_ALLOWED=NO' in workflow
assert "github.event_name == 'workflow_dispatch' && inputs.signed" in workflow
assert 'ios-signing' in workflow
if sys.platform=='darwin': subprocess.run(['plutil','-lint',str(root/'SoraWeather.xcodeproj/project.pbxproj')],check=True)
print(f'PASS: {len(ids)} Xcode objects, source/resource references, plist, scheme, scripts and fixture JSON.')
