#!/usr/bin/env python3
from pathlib import Path
import shutil, subprocess, zipfile
app = Path('build/SoraWeather-unsigned.xcarchive/Products/Applications/SoraWeather.app')
if not (app/'SoraWeather').is_file(): raise SystemExit('Missing archive app executable')
stage = Path('build/unsigned-package')
shutil.rmtree(stage,ignore_errors=True)
(stage/'Payload').mkdir(parents=True)
shutil.copytree(app,stage/'Payload'/app.name,symlinks=True)
# ditto preserves executable bits and symlinks required by iOS bundles.
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(stage/'Payload'),'build/SoraWeather-unsigned.ipa'],check=True)
with zipfile.ZipFile('build/SoraWeather-unsigned.ipa') as z:
    assert 'Payload/SoraWeather.app/SoraWeather' in z.namelist()
print('Unsigned IPA packaged. Requires valid re-signing before installation.')
