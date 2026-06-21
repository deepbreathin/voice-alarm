# Installing VoiceAlarm on an iPhone

There's no App Store listing, so you install it yourself. iOS only runs apps that
are **signed**, and signing for free uses your own Apple ID. Pick whichever path
fits what you have. **No paid Apple Developer account is required** for options A
and B.

> Want to confirm it's safe first? See [`VERIFY-SAFETY.md`](VERIFY-SAFETY.md) —
> it includes a copy-paste prompt for Claude.

---

## Option A — Build from source with Xcode (recommended; needs a Mac)

The most trustworthy option: the phone runs exactly the source you can read.

1. Install **Xcode 16+** from the Mac App Store (free).
2. Get the code:
   ```bash
   git clone https://github.com/deepbreathin/voice-alarm.git
   cd voice-alarm
   git checkout claude/iphone-voice-alarm-app-n1ndba
   open VoiceAlarm.xcodeproj
   ```
3. In Xcode: select the **VoiceAlarm** target → **Signing & Capabilities** →
   tick **Automatically manage signing** and choose your **Apple ID** under
   *Team* (add your Apple ID in Xcode → Settings → Accounts if it's not there —
   a free personal team is fine).
4. Plug in the iPhone, select it as the run destination, press **⌘R**.
5. First launch on the phone: go to **Settings → General → VPN & Device
   Management**, tap your Apple ID, and **Trust** it. Re-open the app.
6. Allow **Notifications** and (when you record) the **Microphone**.

> **Free Apple ID caveat:** apps signed with a free account stop launching after
> **7 days** and must be re-run from Xcode to refresh. A paid Developer account
> ($99/yr) extends this to a year. This is an Apple rule, not the app.

---

## Option B — Sideload the prebuilt app (Mac **or** Windows, no Xcode needed)

Use this if you don't want to build in Xcode. You'll use a free tool that
**re-signs** the app with your own Apple ID and installs it over USB.

1. Download the IPA: on the repo's **Actions** tab open the latest **"Build IPA"**
   run and download the **`VoiceAlarm-unsigned-ipa`** artifact (or, if a release
   was published, grab `VoiceAlarm-unsigned.ipa` from the **Releases** page).
   Unzip the artifact to get `VoiceAlarm-unsigned.ipa`.
2. Install a sideloading tool (both are free, both re-sign with your Apple ID):
   - **[Sideloadly](https://sideloadly.io)** — Windows & macOS, simplest.
   - **[AltStore](https://altstore.io)** — Windows & macOS; can auto-refresh the
     7-day signature in the background.
3. Connect the iPhone, open the tool, drag in `VoiceAlarm-unsigned.ipa`, enter
   your **Apple ID**, and install.
4. On the phone: **Settings → General → VPN & Device Management → Trust** your
   Apple ID, then open the app and allow Notifications/Microphone.

> The IPA from CI is intentionally **unsigned** — Sideloadly/AltStore apply
> *your* signature at install time. The same 7-day free-account limit applies
> (AltStore can auto-refresh it; Sideloadly you re-run weekly).

---

## Option C — TestFlight (nicest install, needs a paid account + a Mac)

If you (or a helper) have a **paid Apple Developer account** and a Mac, TestFlight
gives the smoothest experience: your friend just taps a link and installs via the
TestFlight app, with no trust prompts and 90-day builds.

1. In Xcode, set the team and a unique bundle id, **Product → Archive**.
2. Upload to **App Store Connect**, add the build to **TestFlight**.
3. Invite your friend by email or share the **public TestFlight link**.

---

## Which should I tell my friend to use?

- Friend has a **Mac** and is a bit technical → **Option A** (cleanest, free).
- Friend has **Windows or just wants to drag-and-drop** → **Option B** with
  Sideloadly.
- You have a **paid dev account** and want the polished path → **Option C**.
