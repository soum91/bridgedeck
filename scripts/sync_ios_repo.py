#!/usr/bin/env python3
"""Publish an unsigned, locally verified BridgeDeck IPA in the FlareStore feed."""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

BUNDLE_ID = "com.soum91.bridgedeck"
ICON = (
    "https://raw.githubusercontent.com/soum91/bridgedeck/main/"
    "ios/BridgeDeck/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", required=True, type=Path)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--url", required=True)
    args = parser.parse_args()
    raw = args.ipa.read_bytes()
    if not raw or len(raw) > 200 * 1024 * 1024:
        raise SystemExit("Missing or oversized BridgeDeck IPA")
    if not args.url.startswith("https://github.com/soum91/bridgedeck/releases/download/"):
        raise SystemExit("Unexpected download URL")
    path = Path("repo.json")
    feed = json.loads(path.read_text(encoding="utf-8"))
    apps = feed.setdefault("apps", [])
    app = next((a for a in apps if a.get("bundleIdentifier") == BUNDLE_ID), None)
    if app is None:
        app = {
            "name": "BridgeDeck",
            "bundleIdentifier": BUNDLE_ID,
            "developerName": "soum91",
            "subtitle": "Control Android TV without typing ADB commands",
            "localizedDescription": "Native iPhone dashboard for ADB app management, approved package cleanup, browser/Home preferences and diagnostics. The Android TV companion advertises discovery but does not bypass ADB authorization.",
            "category": "utilities",
            "iconURL": ICON,
            "versions": [],
        }
    version = f"0.1.0.{args.build}"
    item = {
        "version": version,
        "buildVersion": str(args.build),
        "date": datetime.now(timezone.utc).date().isoformat(),
        "localizedDescription": "Native ADB interface, TV discovery, app manager, recovery-first cleanup and readable errors. Requires authorized ADB over your local network.",
        "changelog": "Initial unsigned iPhone prerelease. BridgeDeck TV companion is available separately in EmberTV.",
        "downloadURL": args.url,
        "size": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "minOSVersion": "17.0",
    }
    app["versions"] = [item] + [v for v in app.get("versions", []) if v.get("version") != version][:29]
    app["iconURL"] = ICON
    feed["apps"] = [app] + [a for a in apps if a.get("bundleIdentifier") != BUNDLE_ID]
    path.write_text(json.dumps(feed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Updated BridgeDeck iOS FlareStore feed for " + version)


if __name__ == "__main__":
    main()
