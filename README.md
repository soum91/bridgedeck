# BridgeDeck

Native, approachable ADB controls for iPhone, with a lightweight Android TV companion.

**Status: 0.1.0 development build.** The controller and discovery companion have source implementations, but real-device and CI build verification are required before a stable release.

## What's inside

- **iPhone (ios/)**: SwiftUI dashboard, ADB-over-TCP client, RSA identity stored in iOS Keychain, foreground reconnect, APK installation with the native Files picker, app manager, cleanup, defaults and diagnostics.
- **Sony privacy cleanup**: Optional package candidates from Clean Your TV examples. Only installed packages are shown. Nothing is disabled automatically. A recovery record precedes each disable.
- **Default app controls**: Request the browser role, request a Home activity and verify its resolver, launch a Live TV app. TV button remapping is firmware-specific.
- **Offline error help**: Readable guidance for common ADB/APK failures. No logs leave the phone for AI processing in this version.
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

The workflow produces an unsigned IPA for signing with the user's own certificate. No keys are embedded. SwiftADB is pinned to a source revision under its Apache-2.0 licensing option.

### Android TV

    cd androidtv
    gradle :app:assembleDebug

The workflow uploads a test/debug APK. Debug signing may vary across CI runs. For updates in place and EmberTV publication, configure a secure persistent release-signing key before publishing. Never commit private signing keys.

## References and credits

- Original Clean Your TV: https://github.com/Gathin23/cleanyourtv (MIT license, by Gathin and contributors).
- Upstream Sony device notes: https://github.com/Gathin23/cleanyourtv/tree/main/docs/devices
- SwiftADB: https://github.com/akshaynexus/SwiftADB (GPL-3.0-or-later OR Apache-2.0, external Swift Package using Apache-2.0 alternative).
- Official Android ADB: https://developer.android.com/tools/adb

## Next work

1. Verify both CI builds and fix any compiler failures.
2. Test the initial authorization and reconnection on an Android TV 12 device.
3. Add full installed-package metadata and a model-specific safety review.
4. Add streaming file management, screenshots, batch recovery, and tested default handlers.
5. Add opt-in AI troubleshooting with redacted logs.
6. Evaluate a separately authorized encrypted relay for AP-isolated networks.
