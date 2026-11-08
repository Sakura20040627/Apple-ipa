#!/usr/bin/env python3
"""Real xctrace capture; no synthetic FPS numbers. Simulator results are not device 120Hz validation."""
import subprocess,json,pathlib,os,sys,time,threading,xml.etree.ElementTree as ET
build=pathlib.Path('build');build.mkdir(exist_ok=True)
def run(args,**kwargs):return subprocess.run(args,**kwargs)
root=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','--json']))
saved=build/'simulator-udid.txt'
device=saved.read_text().strip() if saved.exists() else next((d['udid'] for group in root['devices'].values() for d in group if d.get('state')=='Booted'),None)
if not device:raise SystemExit('No booted simulator for SwiftUI trace')
base=['xcodebuild','-project','SoraWeather.xcodeproj','-scheme','SoraWeather','-destination','id='+device,'-derivedDataPath','build/DerivedData','CODE_SIGNING_ALLOWED=NO']
with (build/'ui-build-tests.log').open('w') as log:
 r=run(base+['build-for-testing'],stdout=log,stderr=subprocess.STDOUT)
if r.returncode:raise SystemExit('UI test build failed; see ui-build-tests.log')
with (build/'instruments-templates.log').open('w') as log:run(['xcrun','xctrace','list','templates'],stdout=log,stderr=subprocess.STDOUT)
trace=build/'SwiftUI.trace';report=[];ui_code=1
log=(build/'instruments.log').open('w')
record=subprocess.Popen(['xcrun','xctrace','record','--template','SwiftUI','--device',device,'--all-processes','--time-limit','90s','--output',str(trace),'--no-prompt'],stdout=log,stderr=subprocess.STDOUT)
stop_samples=threading.Event()
def sample_stalled_ui():
 # Collect an actual stack if XCTest stops producing progress, without inventing FPS.
 index=0
 while not stop_samples.wait(30):
  tests=build/'ui-tests.log'
  if not tests.exists() or time.time()-tests.stat().st_mtime < 20:continue
  found=run(['pgrep','-x','SoraWeather'],capture_output=True,text=True)
  for pid in found.stdout.split():
   if not pid.isdigit():continue
   index+=1
   try:run(['sample',pid,'1','1','-file',str(build/('ui-hang-sample-'+str(index)+'.log'))],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=8)
   except subprocess.TimeoutExpired:pass
sampler=threading.Thread(target=sample_stalled_ui,daemon=True);sampler.start()
try:
 with (build/'ui-tests.log').open('w') as tests:
  result=run(base+['test-without-building','-only-testing:SoraWeatherUITests','-resultBundlePath','build/UIRegression.xcresult'],stdout=tests,stderr=subprocess.STDOUT,timeout=480)
 ui_code=result.returncode
 report.append('UI regression exit code: '+str(ui_code))
except subprocess.TimeoutExpired:report.append('UI regression timed out')
finally:stop_samples.set();sampler.join(timeout=9)
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

# UI failures must fail CI. Unsupported simulator profiling is reported separately.
if (build/'UIRegression.xcresult').exists():
 run(['xcrun','xcresulttool','export','attachments','--path','build/UIRegression.xcresult','--output-path','build/ui-attachments'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
sys.exit(ui_code)

# Keep screenshots attached by UI regression tests for visual verification.
