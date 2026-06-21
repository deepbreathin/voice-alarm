# Architecture

VoiceAlarm separates **pure decision logic** (no platform frameworks, fully
unit-testable) from **thin platform adapters** (AVFoundation, UserNotifications,
SwiftUI). This is what makes the app testable without a device and reliable to
ship in one pass.

```
            ┌─────────────────────────────────────────────┐
            │                    Views (SwiftUI)           │
            │  RootView · AlarmsList · AlarmEditor ·        │
            │  RecordingsList · Recorder · RecordingPicker  │
            └───────────────┬─────────────────────────────┘
                            │ @EnvironmentObject
            ┌───────────────▼─────────────────────────────┐
            │                  AppModel (coordinator)       │
            └───┬───────────┬───────────┬───────────┬──────┘
                │           │           │           │
      ┌─────────▼──┐  ┌─────▼─────┐ ┌───▼──────┐ ┌──▼──────────────┐
      │ Recording/ │  │  Audio    │ │ Notif.   │ │ AlarmTrigger    │
      │ Alarm      │  │  services │ │ Service  │ │ Planner (pure)  │
      │ Stores     │  │ (AVFound.)│ │ (UN…)    │ │ + Recurrence    │
      │ (JSON)     │  └───────────┘ └──────────┘ │   Engine (pure) │
      └────────────┘                              └─────────────────┘
```

## Layers

### Models (`VoiceAlarm/Models`) — pure value types
- **`Weekday`** — raw values aligned to `Calendar` numbering (1 = Sunday) so they
  map straight into `DateComponents.weekday`.
- **`TimeOfDay`** — hour/minute, clamped to valid ranges.
- **`Recurrence`** — `.oneOff` / `.weekly(days)` / `.everyNDays(interval, anchor)`.
- **`Recording`**, **`Alarm`** — `Codable` domain models. Recordings persist only
  a *file name*, never an absolute URL (iOS container paths aren't stable).
- **`ScheduledTrigger`** — a platform-agnostic description of one notification.

### Scheduling (`VoiceAlarm/Scheduling`)
- **`RecurrenceEngine`** (extension on `Recurrence`) — `nextOccurrence(after:)`
  and `upcomingOccurrences(after:count:)`. Uses `Calendar` so DST and time zones
  are handled correctly while wall-clock time is preserved. **Pure.**
- **`AlarmTriggerPlanner`** — maps `Alarm`s → `[ScheduledTrigger]`, picks the
  right trigger shape per recurrence, and enforces the 64-notification budget.
  **Pure.**
- **`NotificationService`** — the only place that touches
  `UNUserNotificationCenter`: authorization, category registration, and turning
  `ScheduledTrigger`s into `UNNotificationRequest`s (attaching the prepared
  sound). **Adapter.**

### Audio (`VoiceAlarm/Audio`)
- **`AudioRecorderService`** — `AVAudioRecorder` wrapper with metering.
- **`AudioPlaybackService`** — `AVAudioPlayer` wrapper for previews / full-clip
  playback.
- **`AudioClipPreparer`** — renders the ≤30s CAF notification sound. The trim
  arithmetic (`clippedFrameCount`) is a pure static function so it's unit-tested
  independently of real audio.

### Storage (`VoiceAlarm/Storage`)
- **`JSONFileStore<Value>`** — atomic Codable JSON read/write; directory
  injectable for tests.
- **`AppPaths`** — single source of truth for on-disk layout; injectable base
  directory.
- **`RecordingStore`**, **`AlarmStore`** — `@MainActor ObservableObject`s backing
  the UI; persist via `JSONFileStore`.

### Coordination (`VoiceAlarm/ViewModels/AppModel.swift`)
`AppModel` owns the stores and services and is the one object the views talk to.
Its core responsibility is `rescheduleAll()`, invoked whenever alarms or
recordings change (and on launch / foreground): it renders sounds, asks the
planner for triggers, and hands them to `NotificationService`. It also handles
notification taps (play full clip) and file opens (import).

### App entry (`VoiceAlarm/VoiceAlarmApp.swift`)
`@main` SwiftUI `App` plus an `AppDelegate` that is the
`UNUserNotificationCenterDelegate` — it presents alarms in the foreground and
routes taps into `AppModel`.

## Why "every N days" is special

iOS `UNCalendarNotificationTrigger` repeats only on a fixed calendar period
(every Monday, every day at 7am, etc.). "Every 3 days" is not such a period, so:

1. The planner materialises the next *N* concrete dates (default 16) as
   individual non-repeating triggers.
2. `AppModel.rescheduleAll()` runs on launch / foreground / after a fire, which
   re-fills the window.

This keeps behaviour correct within the pending-notification budget. See
[`iOS-LIMITATIONS.md`](iOS-LIMITATIONS.md).

## Data flow for a firing alarm

1. iOS delivers the scheduled notification with the trimmed CAF sound.
2. If the app is foregrounded, `AppDelegate` shows the banner + sound.
3. User taps → `AppDelegate` → `AppModel.handleNotificationTap` → plays the full
   original recording and re-arms schedules.

## Testing seams

Every pure type takes an injectable `Calendar`/`now`/directory, so tests are
deterministic regardless of the machine's locale, time zone, or clock. The audio
round-trip test synthesizes a tone file and verifies the real trim output.
