# iOS constraints and how VoiceAlarm handles them

This app is designed around several **hard platform limitations**. None of them
can be worked around with more code — they're enforced by iOS. This document is
deliberately blunt so you can evaluate the app accurately without a device.

## 1. Notification sounds are capped at 30 seconds

A local notification can play a **custom sound**, but iOS requires that sound to
be:

- located in the app's `Library/Sounds` directory,
- **≤ 30 seconds** long, and
- in CAF / AIFF / WAV format (not the M4A that recordings and Voice Memos use).

**How VoiceAlarm handles it:** for every recording attached to an enabled alarm,
the app renders a ≤30s CAF copy into `Library/Sounds`
(`AudioClipPreparer`). That trimmed clip is what sounds when the notification
fires in the background. When you **tap** the notification, the app opens and
plays the **full-length** original via `AVAudioPlayer`. The alarm editor warns
you when a clip is longer than 30 seconds.

> There is no public API to play arbitrary-length audio at an exact wall-clock
> time while the app is not running. A 30-second notification sound is the
> longest, most reliable mechanism Apple provides.

## 2. You cannot read the Voice Memos library directly

The system **Voice Memos** app stores its recordings in its own sandbox. There
is **no public API** for another app to enumerate or read that folder. A request
to "open the Voice Memos folder directly" is not possible on iOS for any
third-party app.

**How VoiceAlarm handles it:** two supported import paths that *do* work:

1. **Share out of Voice Memos.** Open a memo → **Share** → choose **VoiceAlarm**
   (or "Save to Files" then import). VoiceAlarm registers as a handler for audio
   files, so it appears in the share sheet and copies the clip in.
2. **Import from Files.** The in-app importer (`square.and.arrow.down`) opens the
   document picker, which can reach iCloud Drive, On My iPhone, and any memos you
   exported to Files.

You can of course also just **record directly in the app**, which sidesteps the
whole issue.

## 3. Silent mode / Focus can suppress sound

Whether a notification *sounds* depends on the ringer switch, Focus modes, and
the per-app notification settings the user grants. A normal app cannot force
sound through silent mode.

Apple does offer **Critical Alerts**, which bypass silent mode and Do Not
Disturb — but that entitlement requires a **special request to Apple** and a
justification, and is generally reserved for health/safety apps. VoiceAlarm is
architected so this could be added (the notification content is built in one
place, `NotificationService`), but it ships using standard alerts. See the note
at the bottom of `NotificationService.swift`.

**Recommendation:** for a reliable wake-up alarm, keep the ringer on and allow
VoiceAlarm's notifications with sound (the app prompts for this on first launch).

## 4. There's a 64 pending-notification limit

iOS keeps at most **64 pending local notifications** per app. "Weekly" alarms use
a single *repeating* trigger per selected weekday, so they're cheap and never
expire. "Every N days" can't be expressed as a native repeating trigger, so the
app schedules a **rolling window** of dated notifications and re-arms it whenever
the app launches or an alarm fires.

**How VoiceAlarm handles it:** `AlarmTriggerPlanner` enforces the budget — it
always keeps the repeating weekly triggers and fills the remaining slots with the
soonest-firing dated triggers, trimming the far future first. This is unit-tested
(`AlarmTriggerPlannerTests.testBudgetKeepsAllRepeatingAndSoonestNonRepeating`).

## 5. "Every N days" needs the app to be opened periodically

Because the rolling window is finite, a long-dormant "every N days" alarm will
eventually exhaust its pre-scheduled occurrences. Opening the app re-arms the
window (the default window of 16 occurrences means you have a wide margin — e.g.
weeks-to-months depending on the interval). Weekly and one-off alarms have no
such caveat.

---

### Summary

| You asked for…                              | Reality on iOS                          | What VoiceAlarm does |
|---------------------------------------------|-----------------------------------------|----------------------|
| Play a voice clip at an alarm time          | ≤30s sound in background; full clip on tap | Trims a CAF + plays full clip on tap |
| Browse the Voice Memos folder directly      | Not possible (sandboxed)                | Import via Share sheet / Files, or record in-app |
| One-off alarm                               | ✅ native one-shot trigger              | ✅ |
| Repeat on chosen weekdays                   | ✅ native weekly triggers               | ✅ |
| Every N days / custom                       | ⚠️ no native trigger                    | Rolling window, re-armed on launch |
| Guaranteed sound through silent mode        | Needs Critical Alerts entitlement       | Standard alerts; documented upgrade path |
