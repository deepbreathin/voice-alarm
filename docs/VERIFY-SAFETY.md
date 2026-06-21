# Is this app safe? How to verify (in minutes)

This app is designed to be **easy to audit**. You don't have to take anyone's
word for it — the claims below are things you (or an AI assistant like Claude)
can confirm directly from the source code in a few minutes.

## The short version

- **Nothing leaves your device.** There is no networking code anywhere in the
  app — no servers, no analytics, no tracking, no "phone home."
- **No third-party code.** The app uses only Apple's own system frameworks.
  There are no external dependencies (no Swift Package, CocoaPods, or Carthage
  manifests) that could pull in someone else's code.
- **It only touches its own sandbox.** Recordings and settings are stored in the
  app's private container. It cannot read your other apps' data, your photos,
  your contacts, etc.
- **Two permissions, both obvious:** the **microphone** (only when you record)
  and **notifications** (so alarms can sound). That's it.

## Verify it yourself — copy/paste these checks

From the project folder, in a terminal:

```bash
# 1) Any networking at all? (Expect: no matches)
grep -rnE "URLSession|URLRequest|URL\(string|dataTask|CFNetwork|Network\.|http://|https://|socket|WKWebView|UIWebView" --include="*.swift" .

# 2) Any analytics/tracking SDKs? (Expect: no matches)
grep -rniE "analytics|firebase|sentry|mixpanel|amplitude|tracking|adjust|appsflyer" --include="*.swift" .

# 3) Any third-party dependencies? (Expect: "no dependency files")
ls Package.swift Podfile Cartfile *.podspec 2>/dev/null || echo "no dependency files"

# 4) Which frameworks does it import? (Expect: only Apple frameworks)
grep -rhoE "^import [A-Za-z_]+" --include="*.swift" . | sort | uniq -c
```

Expected result of #4 — every one of these ships with iOS, none are third-party:

```
AVFoundation        # recording & audio playback
Combine             # SwiftUI state plumbing
Foundation          # standard library
SwiftUI / UIKit     # the user interface
UniformTypeIdentifiers   # recognising audio file types on import
UserNotifications   # scheduling the alarms
XCTest              # tests only (not shipped in the app)
```

## Hand it to Claude (or any AI) — ready-to-paste prompt

> Please do a security review of this iOS app before I install it on my iPhone.
> Be concrete and cite file/line for anything you flag. Specifically confirm or
> refute each of these:
> 1. **No data leaves the device** — search for any networking (`URLSession`,
>    `URLRequest`, `URL(string:)`, `dataTask`, sockets, `WKWebView`, HTTP URLs)
>    and any analytics/tracking SDKs. List every match (I expect none).
> 2. **No third-party code** — check for `Package.swift` dependencies, `Podfile`,
>    `Cartfile`, or any non-Apple `import`. List all imported modules.
> 3. **Permissions** — open `VoiceAlarm/Info.plist` and tell me every permission
>    or capability it declares and why each is needed.
> 4. **File access** — confirm it only reads/writes its own app sandbox
>    (Application Support, the app's Library/Sounds, and files the user
>    explicitly imports), and never accesses arbitrary system paths.
> 5. **No sketchy patterns** — look for dynamic code execution, shell-outs,
>    obfuscated/base64 blobs, or anything that downloads and runs code.
> Then give me a plain-English verdict on whether it's safe to install.

## What each permission is for

| Permission / capability | Where it's declared | Why |
|---|---|---|
| Microphone (`NSMicrophoneUsageDescription`) | `VoiceAlarm/Info.plist` | Only used while you tap record. |
| Notifications | requested at runtime in-app | So alarms can fire when the app is closed. |
| Background audio mode (`UIBackgroundModes: audio`) | `VoiceAlarm/Info.plist` | Lets the full clip keep playing if the app is sent to the background mid-playback. |
| Open audio files (`CFBundleDocumentTypes: public.audio`) | `VoiceAlarm/Info.plist` | So you can share a Voice Memo / pick a file *into* the app. |

## Belt-and-suspenders: build it from source

The most trustworthy way to install is to **build the exact source you just
audited** (see [`INSTALL.md`](INSTALL.md)). Then there's no opaque binary at all —
what runs on the phone is the code in this repo, which is also automatically
built and tested on every change by the CI workflow in
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
