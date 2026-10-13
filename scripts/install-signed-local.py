#!/usr/bin/env python3
"""Run a prepared temporary stage as administrator; never end an active block."""
from pathlib import Path
import datetime
import os
import shutil
import signal
import subprocess
import time

if os.geteuid() != 0:
    raise SystemExit('Run the staged installer through macOS administrator authorization.')
stage = Path(__file__).resolve().parent
app = stage / 'SelfControl.app'
fingerprint = (stage / 'certificate.sha1').read_text().strip()
if len(fingerprint) != 40 or any(c not in '0123456789abcdefABCDEF' for c in fingerprint):
    raise SystemExit('Invalid signing fingerprint.')
requirement = '=certificate leaf = H"' + fingerprint + '"'

def run(args):
    return subprocess.run(args, check=True)

def ensure_idle():
    for settings in Path('/usr/local/etc').glob('.*.plist'):
        result = subprocess.run(['plutil', '-extract', 'BlockIsRunning', 'raw', '-o', '-', str(settings)], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip() == 'true':
            raise SystemExit('Active block detected. Installation stopped without ending it.')

run(['codesign', '--verify', '--deep', '--strict', '-R', requirement + ' and identifier "org.eyebeam.SelfControl"', str(app)])
ensure_idle()
pids = subprocess.run(['pgrep', '-f', '^/Applications/SelfControl.app/Contents/MacOS/SelfControl$'], capture_output=True, text=True)
for value in pids.stdout.splitlines():
    pid = int(value)
    os.kill(pid, signal.SIGTERM)
    for attempt in range(50):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    else:
        raise SystemExit('App did not quit. Installation stopped.')
ensure_idle()
installed = Path('/Applications/SelfControl.app')
pending = Path('/Applications/SelfControl-ui-update.app')
if pending.exists():
    raise SystemExit('An installation stage already exists; stopped.')
backup = Path('/Library/Application Support/SelfControl/LocalBackup')
backup.mkdir(parents=True, exist_ok=True)
os.chmod(backup, 0o700)
suffix = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
previous = backup / ('SelfControl-local-before-ui-' + suffix + '.app')
helper = Path('/Library/PrivilegedHelperTools/org.eyebeam.selfcontrold')
helper_backup = backup / ('selfcontrold-before-ui-' + suffix)
shutil.copy2(helper, helper_backup)
run(['ditto', str(app), str(pending)])
run(['codesign', '--verify', '--deep', '--strict', str(pending)])
ensure_idle()
shutil.move(str(installed), str(previous))
try:
    shutil.move(str(pending), str(installed))
    subprocess.run(['launchctl', 'bootout', 'system/org.eyebeam.selfcontrold'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.copy2(installed / 'Contents/Library/LaunchServices/org.eyebeam.selfcontrold', helper)
    os.chown(helper, 0, 0)
    os.chmod(helper, 0o755)
    run(['codesign', '--verify', '--strict', '-R', requirement + ' and identifier "org.eyebeam.selfcontrold"', str(helper)])
    run(['launchctl', 'bootstrap', 'system', '/Library/LaunchDaemons/org.eyebeam.selfcontrold.plist'])
except Exception:
    if installed.exists():
        shutil.rmtree(installed)
    shutil.move(str(previous), str(installed))
    subprocess.run(['launchctl', 'bootout', 'system/org.eyebeam.selfcontrold'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.copy2(helper_backup, helper)
    os.chown(helper, 0, 0)
    os.chmod(helper, 0o755)
    subprocess.run(['launchctl', 'bootstrap', 'system', '/Library/LaunchDaemons/org.eyebeam.selfcontrold.plist'])
    raise
print('PASS: updated app and helper installed; previous local version backed up; no blocks ended')
