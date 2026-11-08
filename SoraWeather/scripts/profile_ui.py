#!/usr/bin/env python3
"""Real xctrace capture; no synthetic FPS numbers. Simulator results are not device 120Hz validation."""
import subprocess,json,pathlib,os,xml.etree.ElementTree as ET
build=pathlib.Path('build');build.mkdir(exist_ok=True)
def run(args,**kwargs):return subprocess.run(args,**kwargs)
root=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','--json']))
device=next((d['udid'] for group in root['devices'].values() for d in group if d.get('state')=='Booted'),None)
if not device:raise SystemExit('No booted simulator for SwiftUI trace')
base=['xcodebuild','-project','SoraWeather.xcodeproj','-scheme','SoraWeather','-destination','id='+device,'-derivedDataPath','build/DerivedData','CODE_SIGNING_ALLOWED=NO']
with (build/'ui-build-tests.log').open('w') as log:
 r=run(base+['build-for-testing'],stdout=log,stderr=subprocess.STDOUT)
if r.returncode:raise SystemExit('UI test build failed; see ui-build-tests.log')
with (build/'instruments-templates.log').open('w') as log:run(['xcrun','xctrace','list','templates'],stdout=log,stderr=subprocess.STDOUT)
trace=build/'SwiftUI.trace';report=[]
log=(build/'instruments.log').open('w')
record=subprocess.Popen(['xcrun','xctrace','record','--template','SwiftUI','--device',device,'--all-processes','--time-limit','90s','--output',str(trace),'--no-prompt'],stdout=log,stderr=subprocess.STDOUT)
try:
 with (build/'ui-tests.log').open('w') as tests:
  result=run(base+['test-without-building','-only-testing:SoraWeatherUITests','-resultBundlePath','build/UIRegression.xcresult'],stdout=tests,stderr=subprocess.STDOUT,timeout=240)
 report.append('UI regression exit code: '+str(result.returncode))
except subprocess.TimeoutExpired:report.append('UI regression timed out')
try: code=record.wait(timeout=150)
except subprocess.TimeoutExpired:
 record.terminate()
 try:record.wait(timeout=10)
 except subprocess.TimeoutExpired:record.kill();record.wait()
 code=-1
log.close();report.append('SwiftUI xctrace exit code: '+str(code))
if trace.exists() and code==0:
 toc=build/'SwiftUI-toc.xml';run(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(toc)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 if toc.exists():
  try:
   tables=ET.parse(toc).findall('.//table')
   schemas=sorted(set(t.get('schema','') for t in tables))
   report.append('Exported schemas: '+', '.join(schemas))
   for schema in schemas:
    if 'swiftui' in schema.lower() or 'hitch' in schema.lower():
     safe=''.join(c if c.isalnum() else '-' for c in schema)
     output=build/('trace-'+safe+'.xml')
     xpath='/trace-toc/run[@number="1"]/data/table[@schema="'+schema+'"]'
     r=run(['xcrun','xctrace','export','--input',str(trace),'--xpath',xpath,'--output',str(output)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
     if r.returncode==0:report.append('Table exported: '+schema)
  except Exception as e:report.append('Trace export inspection failed: '+type(e).__name__)
else:report.append('SwiftUI capture unavailable or failed; no measured bottleneck or FPS claim is possible.')
report.append('Environment: GitHub macOS runner / iOS simulator. No physical ProMotion iPhone attached; 120fps cannot be certified.')
(build/'performance-summary.txt').write_text('\n'.join(report)+'\n');print('\n'.join(report))
