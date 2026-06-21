import Foundation

/// Pure date math that turns a `Recurrence` + `TimeOfDay` into concrete fire
/// dates. This is the heart of the app and is deliberately free of any
/// platform (UIKit / UserNotifications) dependencies so it can be exhaustively
/// unit-tested with an injected `calendar` and reference `now`.
extension Recurrence {

    /// The next moment this recurrence fires strictly after `now`.
    ///
    /// Returns `nil` when there is no future occurrence (e.g. a one-off whose
    /// time has already passed, or a weekly recurrence with no selected days).
    ///
    /// All calculations honour the supplied `calendar` (and therefore its time
    /// zone and DST rules), preserving the wall-clock time across transitions.
    public func nextOccurrence(
        after now: Date,
        at time: TimeOfDay,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .oneOff(let day):
            let fireDate = time.applied(to: day, calendar: calendar)
            return fireDate > now ? fireDate : nil

        case .weekly(let days):
            guard !days.isEmpty else { return nil }
            // Ask the calendar for the next matching instant for each selected
            // weekday and take the earliest. `Calendar.nextDate` correctly
            // handles week wrap-around and DST.
            let candidates = days.compactMap { weekday -> Date? in
                var components = DateComponents()
                components.weekday = weekday.rawValue
                components.hour = time.hour
                components.minute = time.minute
                components.second = 0
                return calendar.nextDate(
                    after: now,
                    matching: components,
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                )
            }
            return candidates.min()

        case .everyNDays(let rawInterval, let anchorDay):
            let interval = max(1, rawInterval)
            var candidate = time.applied(to: anchorDay, calendar: calendar)
            if candidate > now {
                return candidate
            }
            // Jump close to `now` using whole-day arithmetic, then step the
            // remaining intervals. Adding calendar days (rather than raw
            // seconds) keeps the wall-clock time stable across DST.
            let wholeDays = calendar.dateComponents([.day], from: candidate, to: now).day ?? 0
            let steps = max(0, wholeDays / interval)
            if steps > 0 {
                candidate = calendar.date(byAdding: .day, value: steps * interval, to: candidate) ?? candidate
            }
            var guardrail = 0
            while candidate <= now {
                guard let next = calendar.date(byAdding: .day, value: interval, to: candidate) else {
                    return nil
                }
                candidate = next
                guardrail += 1
                if guardrail > 100_000 { return nil } // paranoia: never spin forever
            }
            return candidate
        }
    }

    /// The next `count` fire dates strictly after `now`, in ascending order.
    ///
    /// Used to pre-schedule a rolling window of notifications for patterns that
    /// iOS cannot express as a single repeating trigger (e.g. "every N days").
    public func upcomingOccurrences(
        after now: Date,
        at time: TimeOfDay,
        calendar: Calendar = .current,
        count: Int
    ) -> [Date] {
        guard count > 0 else { return [] }

        switch self {
        case .oneOff:
            if let date = nextOccurrence(after: now, at: time, calendar: calendar) {
                return [date]
            }
            return []

        case .weekly(let days):
            guard !days.isEmpty else { return [] }
            var results: [Date] = []
            var cursor = now
            var guardrail = 0
            while results.count < count {
                guard let next = nextOccurrence(after: cursor, at: time, calendar: calendar) else { break }
                results.append(next)
                cursor = next
                guardrail += 1
                if guardrail > count * 8 + 16 { break }
            }
            return results

        case .everyNDays(let rawInterval, _):
            let interval = max(1, rawInterval)
            var results: [Date] = []
            guard var cursor = nextOccurrence(after: now, at: time, calendar: calendar) else { return [] }
            results.append(cursor)
            while results.count < count {
                guard let next = calendar.date(byAdding: .day, value: interval, to: cursor) else { break }
                results.append(next)
                cursor = next
            }
            return results
        }
    }
}
