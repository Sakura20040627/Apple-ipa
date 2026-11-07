#!/usr/bin/env python3
"""Manual signing, no App Store upload. Run only on a trusted macOS runner."""
import base64, datetime, os, pathlib, plistlib, secrets, shlex, subprocess, tempfile

def run(args, *, capture=False, quiet=False):
    r = subprocess.run(args, stdout=subprocess.PIPE if capture or quiet else None, stderr=subprocess.PIPE if quiet else None)
    if r.returncode: raise RuntimeError('Signing/build command failed; inspect the preceding build log (secret command arguments omitted).')
    return r.stdout if capture else None

def required(name):
    v=os.environ.get(name,'')
    if not v: raise RuntimeError('Missing required signing configuration: '+name)
    return v

def main():
    p12=required('P12_BASE64'); password=required('P12_PASSWORD'); profile=required('PROFILE_BASE64'); team=required('TEAM_ID')
    bundle=os.environ.get('BUNDLE_ID','app.sora.weather'); method=os.environ.get('EXPORT_METHOD','release-testing')
    if method not in ['release-testing','debugging','app-store-connect']: raise RuntimeError('Invalid export method')
    build=pathlib.Path('build'); build.mkdir(exist_ok=True)
    original=shlex.split(run(['security','list-keychains','-d','user'],capture=True).decode())
    installed=[]
    with tempfile.TemporaryDirectory(prefix='sora-signing-') as temp:
        root=pathlib.Path(temp); keychain=root/'signing.keychain-db'; keypass=secrets.token_urlsafe(32)
        cert=root/'cert.p12'; prov=root/'profile.mobileprovision'
        cert.write_bytes(base64.b64decode(p12,validate=True)); cert.chmod(0o600)
        prov.write_bytes(base64.b64decode(profile,validate=True)); prov.chmod(0o600)
        try:
            decoded=plistlib.loads(run(['security','cms','-D','-i',str(prov)],capture=True,quiet=True))
            entitlements=decoded['Entitlements']
            if team not in decoded['TeamIdentifier']: raise RuntimeError('Provisioning team mismatch')
            if entitlements.get('application-identifier') != team+'.'+bundle: raise RuntimeError('Profile must match explicit bundle ID')
            if decoded['ExpirationDate'].replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc): raise RuntimeError('Expired profile')
            debug=bool(entitlements.get('get-task-allow',False))
            if method=='debugging' and not debug: raise RuntimeError('Development export requires a development profile')
            if method!='debugging' and debug: raise RuntimeError('Distribution export requires a distribution profile')
            if method=='release-testing' and not decoded.get('ProvisionedDevices'): raise RuntimeError('Ad Hoc profile must include device UDIDs')
            if method=='app-store-connect' and decoded.get('ProvisionedDevices'): raise RuntimeError('App Store export requires an App Store profile')
            for directory in [pathlib.Path.home()/'Library/MobileDevice/Provisioning Profiles', pathlib.Path.home()/'Library/Developer/Xcode/UserData/Provisioning Profiles']:
                directory.mkdir(parents=True,exist_ok=True); dst=directory/(decoded['UUID']+'.mobileprovision'); dst.write_bytes(prov.read_bytes()); installed.append(dst)
            run(['security','create-keychain','-p',keypass,str(keychain)],quiet=True)
            run(['security','set-keychain-settings','-lut','21600',str(keychain)],quiet=True)
            run(['security','unlock-keychain','-p',keypass,str(keychain)],quiet=True)
            run(['security','import',str(cert),'-k',str(keychain),'-P',password,'-T','/usr/bin/codesign','-T','/usr/bin/security'],quiet=True)
            run(['security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',keypass,str(keychain)],quiet=True)
            run(['security','list-keychains','-d','user','-s',str(keychain),*original],quiet=True)
            identity='Apple Development' if debug else 'Apple Distribution'
            run(['xcodebuild','-project','SoraWeather.xcodeproj','-scheme','SoraWeather','-configuration','Release','-destination','generic/platform=iOS','-archivePath','build/SoraWeather-signed.xcarchive','archive','CODE_SIGN_STYLE=Manual','DEVELOPMENT_TEAM='+team,'PRODUCT_BUNDLE_IDENTIFIER='+bundle,'CODE_SIGN_IDENTITY='+identity,'PROVISIONING_PROFILE_SPECIFIER='+decoded['UUID']])
            options={'method':method,'destination':'export','teamID':team,'signingStyle':'manual','signingCertificate':identity,'provisioningProfiles':{bundle:decoded['UUID']},'manageAppVersionAndBuildNumber':False}
            export=root/'ExportOptions.plist'; export.write_bytes(plistlib.dumps(options))
            run(['xcodebuild','-exportArchive','-archivePath','build/SoraWeather-signed.xcarchive','-exportPath','build/export','-exportOptionsPlist',str(export)])
            run(['codesign','--verify','--deep','--strict','build/SoraWeather-signed.xcarchive/Products/Applications/SoraWeather.app'])
        finally:
            subprocess.run(['security','list-keychains','-d','user','-s',*original],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            subprocess.run(['security','delete-keychain',str(keychain)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            for dst in installed: dst.unlink(missing_ok=True)
if __name__=='__main__':
    try: main()
    except Exception as error: raise SystemExit(str(error))
