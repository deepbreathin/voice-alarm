# Testing

## Running the tests

```bash
make test
# or explicitly:
xcodebuild test -project VoiceAlarm.xcodeproj -scheme VoiceAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

In Xcode: press **⌘U**.

## Philosophy

The scheduling and persistence logic is pure Swift with injectable
`Calendar` / `now` / directory dependencies, so the tests are **deterministic**:
they pin a fixed UTC calendar (and an `America/New_York` calendar for DST cases)
and a fixed reference date (`2026-06-21 08:00`, a Sunday). Results do not depend
on the machine's locale, time zone, or wall clock.

## What's covered

### `RecurrenceEngineTests`
The heart of the app.
- One-off: future date, past date, "today but earlier/later than now".
- Weekly: empty set → never; next single day; "today, later" returns today;
  "today, earlier" rolls to next week; earliest of multiple days.
- Every N days: anchor today (earlier/later), anchor in the past jumping forward,
  interval clamped to ≥ 1.
- `upcomingOccurrences`: correct dates and counts for weekly/every-N/one-off;
  results strictly increasing.
- **DST**: wall-clock time preserved across US spring-forward (every-N-days) and
  fall-back (weekly).

### `AlarmTriggerPlannerTests`
- Disabled / no-recording / empty-weekly alarms produce no triggers.
- One-off → a single non-repeating trigger with full date components.
- Weekly → one *repeating* trigger per weekday with correct `weekday` component
  and unique identifiers.
- Every-N-days → a window of non-repeating triggers spaced by the interval.
- 64-notification budget: all repeating triggers retained, remaining slots filled
  with the soonest dated triggers.

### `ModelTests`
`Weekday` (numbering, ordering, presets, Codable), `TimeOfDay` (clamping,
comparison, conversions), `Alarm` (schedulability, next-fire, Codable across all
recurrence kinds), `Recurrence.isRepeating`.

### `FormattersTests`
Duration formatting, recurrence descriptions (presets + Monday-first custom day
ordering), and relative next-fire descriptions (Today / Tomorrow / dated).

### `StorageTests`
`JSONFileStore` (missing/empty/round-trip/nested dirs), `RecordingStore`
(upsert/replace/rename/delete + file removal, dropping entries whose file
vanished, persistence across instances), `AlarmStore` (time sorting,
enable/disable, delete, unlinking a deleted recording).

### `AudioHelperTests`
Pure helpers: clip frame-count math (under/over limit, zero guards), deterministic
CAF sound file naming, import file-name sanitising and title derivation.

### `AudioClipPreparerIntegrationTests`
Real audio I/O on the simulator: synthesizes a tone WAV, then verifies a short
clip is copied whole, a 40s clip is trimmed to ~30s, re-preparing replaces the
output, and removal deletes the file.

### UI tests (`VoiceAlarmUITests`)
Launch + screenshot, tab presence, opening the new-alarm editor, and opening the
recorder sheet. Kept intentionally light and resilient (no reliance on the system
permission dialogs).

## CI

`.github/workflows/ci.yml` runs the full suite on macOS for every push and PR,
twice: against the committed `VoiceAlarm.xcodeproj`, and against a fresh
`xcodegen generate`. Test result bundles are uploaded as artifacts.
