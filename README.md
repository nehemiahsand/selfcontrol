# [SelfControl][website]

<p align="center">
    <img src="./.github/docs/screenshot.png" />
</p>

## About

SelfControl is a free and open-source application for macOS that lets you block **your own** access to distracting websites, your mail servers, or anything else on the Internet. Just set a period of time to block for, add sites to your blocklist, and click "Start Block". Until that timer expires, you will be unable to access those sites—even if you restart your computer or delete the application.

## Clock-change protection in this fork

New blocks use elapsed time rather than the editable Mac calendar clock. Moving
Date & Time forward or backward, changing time zones, or automatic clock
corrections cannot shorten or extend an active block. The countdown, expiry
decision, and in-app recovery-button eligibility use the same remaining time.

- On macOS 10.12 and later, sleep counts toward the duration using
  `mach_continuous_time()`. The older-system fallback excludes sleep.
- Closing the interface or restarting the daemon within the same boot preserves
  elapsed time. The daemon saves a checkpoint every 15 seconds while running.
- After a Mac reboot, the countdown resumes from the last successfully saved
  remainder. **Time powered off does not count.** Recent progress not saved before
  a crash may need to be waited again. This deliberately avoids trusting a
  changed calendar clock after reboot and needs no server or internet connection.
- A missing or invalid elapsed-time record keeps a new-format block active
  instead of falling back to the calendar deadline.
- Settings synchronization uses revisions, so moving the clock backward cannot
  prevent new timer checkpoints from being written.
- Invalid extensions now return immediately instead of continuing to change the
  deadline after reporting an error.

This protects against clock changes, not an administrator deliberately editing
root-owned state, removing firewall rules, using the separate recovery utility,
or replacing the software. Blocks started by an older version retain their old
timing behavior; finish them before installing this fork. Existing upstream
network-blocking limitations remain.

### Development verification

This custom build also preserves the complete active blocklist when adding sites,
including during rule repair. Its official-release updater and update controls
are removed so an update cannot silently replace the custom timer implementation.

Use **Import > Site Bundles** in the list editor to preview and add YouTube,
Reddit, or Instagram domains. These lists are editable before a block starts and
are unavailable while viewing an active list or using allowlist mode. They are
starting lists, not exhaustive coverage of future domains or cached content.

The timer shows **Block active** only when the daemon has recently observed an
enabled packet filter, a referenced SelfControl anchor with loaded block rules,
and the expected hosts marker (for blocklist mode). Missing, unsuccessful, or
more than 45-second-old checks show **Protection needs attention**. This does not
verify every individual rule or prove that VPNs/proxies and every browser route
are covered; the label's tooltip states its scope.

Run `bash SelfControlTests/run-clock-tests.sh` on a Mac with the Xcode command-line
tools. The standalone tests exercise the clock model and the real expiry,
extension, checkpoint, and settings-sync code with simulated clocks and inert
firewall/storage adapters. They do not change the system time or activate a block.
The OS clock smoke test requires permission to read `kern.bootsessionuuid`, which
some execution sandboxes prohibit.

Before using this as an installed blocker, build the complete app with Xcode and
its CocoaPods dependencies, configure signing for your own development team
(including the helper/XPC signing requirements), and test a short block on a test
Mac through sleep, reboot, date changes, and normal expiry.

The complete app and helper targets have built successfully with Xcode 27 on
Apple silicon, with signing disabled. `bash scripts/build-local.sh` reproduces
that build after installing the Podfile dependencies. It produces the bundle at
`build/DerivedData/Build/Products/Debug/SelfControl.app` and records diagnostics in
`build/xcode-build.log`. A locally signed build is installed on this Mac. A live one-minute
`example.com` block verified actual blocking, healthy firewall status, automatic
expiry, removal of the test hosts entry, and restored HTTP access. Physical
sleep/reboot/date-change tests have not been performed; those cases are covered
by the simulated regression suite. The safe regression suite passes 104 assertions
plus configuration checks; the edited interfaces also compile with `ibtool`.

## Local interface

The local version uses a spacious native layout with large duration text,
clear actions, and system colors for light and dark appearance. The main and
extension sliders select whole days from 1 to 30. Duration storage remains in
minutes for CLI and existing-block compatibility. Saved new-block selections
are rounded up to whole days and clamped to this range; active timers are not
changed. The helper accepts extensions of up to 30 days per request.

Run `bash SelfControlTests/run-slider-tests.sh` for day conversion and binding
checks, and `bash SelfControlTests/run-clock-tests.sh` for clock and daemon
regressions. The staged administrator installer in
`scripts/install-signed-local.py` refuses active blocks and backs up the
previous local app and helper before replacing them.

## Credits

Developed by [Charlie Stigler](http://charliestigler.com), [Steve Lambert](http://visitsteve.com), and [others](https://github.com/SelfControlApp/selfcontrol/graphs/contributors). Your contributions very welcome!

SelfControl is now available in 12 languages thanks to [the fine translators credited here](https://github.com/SelfControlApp/selfcontrol/wiki/Translation-Credits).

## License

SelfControl is free software under the GPL. See [this file](./COPYING) for more details.

## Building For Development

Users should always download the latest version of SelfControl from [our website][website]. If you want to contribute to SelfControl, you'll need to learn to build it for development. This can only be done on a Mac running a modern version of macOS.

1. Clone the SelfControl repo from GitHub.
2. Make sure you have a recent version of Xcode and the Xcode command-line tools installed.
3. Install [CocoaPods](https://cocoapods.org/): `sudo gem install cocoapods`
4. Install the SelfControl dependencies using CocoaPods: `pod install`
5. Open the `selfcontrol.xcworkspace` file (**NOT** `selfcontrol.xcodeproj`)
6. Build and run (you may need to update/remove code signing settings to make it build properly)

[website]: https://selfcontrolapp.com/

### Local signing

`python3 scripts/build-signed-local.py` builds with the isolated local certificate
under `build/local-signing/`. App, CLI, and helper ownership checks pin that
certificate. The build does not install anything or change an active block, and
requires no paid developer account. Private signing files are kept in the ignored
build directory; no certificate was added to system trust and the user's keychain
search list was restored. Preserve these files for future builds of this local
installation.

The previous installed app and secured settings were backed up under
`/Library/Application Support/SelfControl/LocalBackup/` before replacing them.
The user's previous block was ended at their explicit request.
