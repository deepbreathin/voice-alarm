# VoiceAlarm

An iPhone app that plays **your own voice recordings as alarms**. Record a clip
(or import one from Files / share it out of Voice Memos), pick a time, choose how
it repeats — once, on specific weekdays, or every *N* days — and VoiceAlarm
sounds it at the appointed time.

Built with SwiftUI for iOS 17+. The scheduling logic is pure, dependency-free
Swift and is covered by an extensive automated test suite that runs in CI on
every push.

---

## Features

- 🎙️ **Record voice clips in-app** with a live level meter and timer.
- 📥 **Import audio** from the Files app / iCloud Drive, or **share a memo out of
  Voice Memos** straight into VoiceAlarm (Share sheet → *VoiceAlarm*).
- ▶️ **Preview** any clip before assigning it.
- ⏰ **Create alarms** that play a chosen recording at a chosen time.
- 🔁 **Flexible repeat options**:
  - **Once** on a specific date,
  - **Weekly** on any subset of Monday–Sunday (with Weekdays / Weekends / Every
    day quick-picks),
  - **Every N days** from a start date.
- 🔔 Fires via the system notification scheduler so it works when the app is in
  the background or closed. Tapping the notification opens the app and plays the
  **full-length** recording.
- 🗂️ Manage recordings (rename, delete) and alarms (enable/disable, edit, delete).
- ♿ Accessibility labels throughout; respects the system 12/24-hour clock and
  locale.

> **Please read [`docs/iOS-LIMITATIONS.md`](docs/iOS-LIMITATIONS.md).** iOS places
> hard constraints on what an alarm app can do (notification sounds are capped at
> 30 seconds, apps cannot reach the Voice Memos library directly, and silent mode
> affects playback). The app is designed around these constraints and the doc
> explains exactly how — important context if you're evaluating the app without a
> device in hand.

---

## Quick start

You need a Mac with **Xcode 16 or newer**.

```bash
git clone <this repo>
cd voice-alarm
open VoiceAlarm.xcodeproj      # or: make open
```

Then in Xcode: select the **VoiceAlarm** scheme, choose an iPhone simulator (or
your device), and press **⌘R** to run, or **⌘U** to run all the tests.

To run an alarm on a **physical iPhone** you must set your signing team:
select the *VoiceAlarm* target → *Signing & Capabilities* → pick your Apple ID
team. (Notifications and microphone work fully only on a real device or a
simulator; alarm *sounds* are best verified on a real device.)

### If the project won't open

The committed `VoiceAlarm.xcodeproj` is generated from
[`project.yml`](project.yml). If you ever hit a project-format issue, regenerate
it deterministically:

```bash
brew install xcodegen   # once
xcodegen generate       # or: make generate
```

---

## Testing

```bash
make test       # runs unit + UI tests on a simulator
```

The suite covers the recurrence engine (including DST transitions), the
notification trigger planner and its 64-notification budget, persistence,
formatting, audio-clip trimming (a real read/trim/write round-trip), and the
import helpers, plus UI smoke tests. See [`docs/TESTING.md`](docs/TESTING.md).

CI (GitHub Actions, `.github/workflows/ci.yml`) builds and tests on macOS for
every push — once against the committed project and once against a fresh
XcodeGen regeneration.

---

## How it works (in one paragraph)

Recordings and alarms are stored as JSON in Application Support; audio files live
in a `Recordings` directory. When alarms change, `AppModel` asks the pure
`AlarmTriggerPlanner` to turn every enabled alarm into a set of
`ScheduledTrigger` values, renders a ≤30s CAF "alarm sound" for each into
`Library/Sounds`, and registers them as `UNCalendarNotificationTrigger`s. Weekly
alarms use one repeating trigger per weekday; "every N days" alarms pre-schedule
a rolling window of dated triggers that is re-armed whenever the app launches or
an alarm fires. Tapping a delivered notification routes back into `AppModel`,
which plays the full original recording. Full detail in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Project layout

```
VoiceAlarm/                 App source
  Models/                   Weekday, TimeOfDay, Recurrence, Recording, Alarm, ScheduledTrigger
  Scheduling/               RecurrenceEngine, AlarmTriggerPlanner, NotificationService
  Audio/                    Recorder, Playback, ClipPreparer (≤30s CAF)
  Storage/                  JSON file store, Recording/Alarm stores, paths
  Services/                 Import (Files / Voice Memos share)
  ViewModels/               AppModel (coordinator)
  Views/                    SwiftUI screens
  Utilities/                Formatters
VoiceAlarmTests/            Unit tests (pure logic + audio round-trip)
VoiceAlarmUITests/          UI smoke tests
docs/                       Architecture, iOS limitations, testing, build notes
project.yml                 XcodeGen definition (source of truth)
VoiceAlarm.xcodeproj        Pre-generated project (open this)
```

## License

MIT — see [`LICENSE`](LICENSE).
