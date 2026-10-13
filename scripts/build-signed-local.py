#!/usr/bin/env python3
"""Build a locally signed copy without installing it or changing active blocks."""
from pathlib import Path
import os
import plistlib
import shlex
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.chdir(root)
signing = root / 'build/local-signing'
keychain = signing / 'local.keychain-db'
if not keychain.exists() or not (signing / 'certificate.sha1').exists():
    raise SystemExit('Prepare the isolated local signing identity first.')
fingerprint = (signing / 'certificate.sha1').read_text().strip()
if len(fingerprint) != 40 or any(c not in '0123456789abcdefABCDEF' for c in fingerprint):
    raise SystemExit('Invalid local certificate fingerprint.')
password = (signing / 'password').read_text().strip()

def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

certificate = f'certificate leaf = H"{fingerprint}"'
app_requirement = certificate + ' and (identifier "org.eyebeam.SelfControl" or identifier "org.eyebeam.selfcontrol-cli")'
helper_requirement = certificate + ' and identifier "org.eyebeam.selfcontrold"'
app_info = plistlib.loads((root / 'Info.plist').read_bytes())
app_info['SMPrivilegedExecutables'] = {'org.eyebeam.selfcontrold': helper_requirement}
helper_info = plistlib.loads((root / 'Daemon/selfcontrold-Info.plist').read_bytes())
helper_info['SMAuthorizedClients'] = [app_requirement]
cli_info = plistlib.loads((root / 'selfcontrol-cli-Info.plist').read_bytes())
cli_info['SMPrivilegedExecutables'] = app_info['SMPrivilegedExecutables']
for filename, info in [('App-Info.plist', app_info), ('Helper-Info.plist', helper_info), ('CLI-Info.plist', cli_info)]:
    (signing / filename).write_bytes(plistlib.dumps(info, sort_keys=False))
config = signing / 'LocalSigningConfig.h'
config.write_text(f'#define SELFCONTROL_LOCAL_SIGNING_CERTIFICATE "{fingerprint}"\n')
derived = root / 'build/SignedDerivedData'
args = ['xcodebuild', '-workspace', 'SelfControl.xcworkspace', '-scheme', 'SelfControl',
        '-configuration', 'Debug', '-derivedDataPath', str(derived),
        'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'MACOSX_DEPLOYMENT_TARGET=12.0',
        'ONLY_ACTIVE_ARCH=YES', 'ENABLE_USER_SCRIPT_SANDBOXING=NO',
        'GCC_PRECOMPILE_PREFIX_HEADER=NO', 'ENABLE_DEBUG_DYLIB=NO',
        f'SELFCONTROL_APP_INFO_PLIST={signing / "App-Info.plist"}',
        f'SELFCONTROL_HELPER_INFO_PLIST={signing / "Helper-Info.plist"}',
        f'SELFCONTROL_CLI_INFO_PLIST={signing / "CLI-Info.plist"}',
        f'OTHER_CFLAGS=$(inherited) -include {shlex.quote(str(config))}', 'build']
if '--sign-only' not in sys.argv:
    with (root / 'build/signed-build.log').open('w') as log:
        run(args, stdout=log, stderr=subprocess.STDOUT)
app = derived / 'Build/Products/Debug/SelfControl.app'
run(['security', 'unlock-keychain', '-p', password, str(keychain)], stdout=subprocess.DEVNULL)
def sign(path, identifier=None):
    args = ['codesign', '--force', '--sign', fingerprint, '--keychain', str(keychain),
            '--timestamp=none', '--options', 'runtime']
    if identifier:
        args += ['--identifier', identifier]
    run(args + [str(path)], stdout=subprocess.DEVNULL)
# Inside-out signing; never use --deep to mask unexpected unsigned components.
for dylib in (app / 'Contents').rglob('*.dylib'):
    if not dylib.is_symlink():
        sign(dylib)
for framework in (app / 'Contents/Frameworks').glob('*.framework'):
    sign(framework)
sign(app / 'Contents/MacOS/selfcontrol-cli', 'org.eyebeam.selfcontrol-cli')
sign(app / 'Contents/MacOS/SCKillerHelper', 'SCKillerHelper')
sign(app / 'Contents/Library/LaunchServices/org.eyebeam.selfcontrold', 'org.eyebeam.selfcontrold')
sign(app, 'org.eyebeam.SelfControl')
run(['codesign', '--verify', '--deep', '--strict', str(app)])
run(['codesign', '--verify', '-R', '=' + helper_requirement,
     str(app / 'Contents/Library/LaunchServices/org.eyebeam.selfcontrold')])
run(['codesign', '--verify', '-R', '=' + app_requirement, str(app)])
run(['codesign', '--verify', '-R', '=' + app_requirement, str(app / 'Contents/MacOS/selfcontrol-cli')])
print('PASS: signed bundle, helper ownership, and CLI ownership')
print(f'Prepared local app: {app}')
