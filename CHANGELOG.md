# Changelog

## Next iPhone prerelease (2026-10-30)

- Replaced the oversized connected-state address form with a compact ADB status and a first-screen toolbox linking to Apps, Clean, Defaults, and ADB commands.
- Added a dedicated, categorized common-command screen with readable command descriptions, raw command preview, and immediate result sheets.
- Added visible rule-based error help and an optional on-device AI explanation from each command result.
- Dismisses the keyboard when ADB connects, adds a keyboard Done button, and restores access to the bottom tab bar.
- Added safe review of installed third-party apps in Clean, while preserving protected-system exclusions and recovery snapshots.
- Added installed-app choices for browser and tuner, plus Home activity discovery.
- Rechecks the existing ADB TCP connection when returning to the foreground and reconnects when the session has expired.
- Builds with a modern iOS SDK to include Apple Foundation Models where supported. No claim of privileged TV access from the companion alone.

## 0.1.0 (2026-10-30)

- Native SwiftUI iPhone controller with persistent ADB RSA identity.
- Direct ADB shell commands, package listing, native APK import and streaming installation.
- Sony optional privacy-cleanup candidates, protected package list, recovery snapshots and reversible disable.
- Browser, Home and TV app controls with explicit Android platform limitations.
- Offline error explanations, optional Apple on-device AI and advanced shell.
- Android TV companion for local discovery and read-only status.
- CI definitions for an unsigned iOS IPA and Android TV debug APK.
