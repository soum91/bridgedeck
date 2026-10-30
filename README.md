# BridgeDeck

Native, approachable ADB controls for iPhone, with a lightweight Android TV companion.

**Status: 0.1.0 prerelease.** The unsigned iPhone IPA and permanently signed Android TV companion have passed CI compilation. Real-device connectivity and feature testing are still required before calling this stable.

## Install and update

- **FlareStore iPhone source:** https://raw.githubusercontent.com/soum91/bridgedeck/main/repo.json
- **Latest iPhone unsigned IPA:** https://github.com/soum91/bridgedeck/releases
- **EmberTV Android TV catalog:** https://raw.githubusercontent.com/soum91/embertv/main/repo.json
- **Signed TV companion releases:** https://github.com/soum91/embertv/releases

The iPhone app requires signing with your own iOS certificate. The Android TV companion is published through EmberTV using its permanent Android signing certificate, so subsequent signed versions can update in place. If an earlier **debug-signed** BridgeDeck TV APK was installed, uninstall that debug build once before installing the permanently signed release. Installing the companion does not grant ADB authority.

## What's inside

- **iPhone (ios/)**: SwiftUI dashboard, ADB-over-TCP client, RSA identity stored in iOS Keychain, foreground reconnect, APK installation with the native Files picker, app manager, cleanup, defaults and diagnostics.
- **Sony privacy cleanup**: Optional package candidates from Clean Your TV examples. Only installed packages are shown. Nothing is disabled automatically. A recovery record precedes each disable.
- **Default app controls**: Request the browser role, request a Home activity and verify its resolver, launch a Live TV app. TV button remapping is firmware-specific.
- **Offline error help**: Readable guidance for common ADB/APK failures plus an optional on-device Apple Foundation Models explainer when built with the iOS 26+ SDK and available on the device. Logs are not uploaded.
- **Android TV (androidtv/)**: Native Leanback companion with mDNS discovery and read-only status. No privileged command execution or remote shell.

## Android TV 12 compatibility

Standard code-based wireless pairing on TVs requires Android 13 or later. Android TV 12 targets must already expose an authorized ADB-over-TCP endpoint. Some devices offer Network debugging; others require an initial computer-based setup. Installing the companion does not enable ADB or grant shell permissions.

Check Settings > System > Developer options. If Network debugging is available, enable it and authorize BridgeDeck's RSA key on the TV. Otherwise, use the documented supported computer/USB TCP setup as available for the hardware.

The phone and TV need network reachability. Separate 2.4 and 5 GHz bands are fine if the router permits cross-band communication. AP isolation may block both mDNS and ADB. Do not expose ADB port 5555 to the public internet.

## TV cleanup safety

This app integrates reviewable **candidates**, not an unreviewed Clean Your TV script. Upstream Sony profiles are not universally safe across models or firmware revisions. BridgeDeck checks the installed package list before showing candidates and refuses protected components including Android core, Sony tuner and input services, Bravia Sync, the stock launcher, and setupwraith.

Before disabling a package, BridgeDeck saves JSON under Files > On My iPhone > BridgeDeck > Recovery. It records the original disabled list, Home resolver, build and target package. A selected package can be restored by re-enabling it. This initial implementation does not yet offer batch rollback.

Package categories are about optional telemetry and promotions, **not evidence an app is spyware**. Do not infer malicious intent from package names alone.

The browser role may be unavailable on a TV. Sony firmware may override Home preferences. The tuner uses Sony's TV Input Framework and has no universal "force default tuner" ADB switch. BridgeDeck reports results honestly.

## Build

### iPhone

Install XcodeGen and use Xcode 16 or later:

    cd ios
    xcodegen generate
    xcodebuild -project BridgeDeck.xcodeproj -scheme BridgeDeck -sdk iphoneos CODE_SIGNING_ALLOWED=NO build

The workflow produces an unsigned IPA for signing with the user's own certificate. No keys are embedded. SwiftADB is locally vendored from source revision 1044bec under its Apache-2.0 licensing option, with the unavailable Security SDK identity call disabled for legacy TCP-only use.

### Android TV

    cd androidtv
    gradle :app:assembleDebug

The source repository workflow uploads a test/debug APK. Use the permanently signed APK published through EmberTV for installations and update continuity. Never commit private signing keys.

## References and credits

- Original Clean Your TV: https://github.com/Gathin23/cleanyourtv (MIT license, by Gathin and contributors).
- Upstream Sony device notes: https://github.com/Gathin23/cleanyourtv/tree/main/docs/devices
- SwiftADB: https://github.com/akshaynexus/SwiftADB (GPL-3.0-or-later OR Apache-2.0, vendored Swift Package using Apache-2.0 alternative). BridgeDeck's local compatibility patch disables its broken TLS identity path; TLS pairing is not claimed as functional.
- Official Android ADB: https://developer.android.com/tools/adb

## Next work

1. Test the initial authorization and reconnection on an Android TV 12 device.
2. Add full installed-package metadata and a model-specific safety review.
3. Add streaming file management, screenshots, batch recovery, and tested default handlers.
4. Add opt-in AI troubleshooting with redacted logs.
5. Evaluate a separately authorized encrypted relay for AP-isolated networks.
