import Foundation

/// Turns an `Alarm` into the concrete set of `ScheduledTrigger`s that should be
/// registered with the system. Pure and fully testable.
///
/// ## Why this is non-trivial
/// iOS local notifications can repeat on a *fixed calendar period* (e.g. "every
/// Monday at 7:00") via a single repeating `UNCalendarNotificationTrigger`, but
/// they cannot natively express "every N days". For that pattern we materialise
/// a rolling window of individual non-repeating triggers and re-arm the window
/// whenever the app launches or an alarm fires.
public struct AlarmTriggerPlanner {

    /// iOS allows at most 64 pending notification requests per app. We keep a
    /// margin below that ceiling and divide the remaining budget across alarms.
    public static let systemPendingLimit = 64

    /// How many occurrences to pre-schedule for a single "every N days" alarm.
    public let windowSizePerIntervalAlarm: Int

    public init(windowSizePerIntervalAlarm: Int = 16) {
        self.windowSizePerIntervalAlarm = max(1, windowSizePerIntervalAlarm)
    }

    /// Builds the triggers for one alarm.
    public func triggers(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar = .current
    ) -> [ScheduledTrigger] {
        guard alarm.isSchedulable else { return [] }

        switch alarm.recurrence {
        case .oneOff:
            guard let fire = alarm.recurrence.nextOccurrence(after: now, at: alarm.time, calendar: calendar) else {
                return []
            }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            return [
                ScheduledTrigger(
                    id: alarm.id.uuidString,
                    alarmID: alarm.id,
                    dateComponents: comps,
                    repeats: false,
                    fireDate: fire
                )
            ]

        case .weekly(let days):
            // One repeating trigger per selected weekday — iOS handles the
            // weekly repeat itself, so these never need re-arming.
            return days.sorted().map { weekday in
                var comps = DateComponents()
                comps.weekday = weekday.rawValue
                comps.hour = alarm.time.hour
                comps.minute = alarm.time.minute
                let fire = alarm.recurrence
                    .nextOccurrence(after: now, at: alarm.time, calendar: calendar)
                return ScheduledTrigger(
                    id: "\(alarm.id.uuidString).wd\(weekday.rawValue)",
                    alarmID: alarm.id,
                    dateComponents: comps,
                    repeats: true,
                    // The per-weekday next date isn't meaningful here; the list
                    // min is the alarm's next fire and is computed elsewhere.
                    fireDate: fire
                )
            }

        case .everyNDays:
            let dates = alarm.recurrence.upcomingOccurrences(
                after: now,
                at: alarm.time,
                calendar: calendar,
                count: windowSizePerIntervalAlarm
            )
            return dates.enumerated().map { index, fire in
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                return ScheduledTrigger(
                    id: "\(alarm.id.uuidString).n\(index)",
                    alarmID: alarm.id,
                    dateComponents: comps,
                    repeats: false,
                    fireDate: fire
                )
            }
        }
    }

    /// Builds triggers for many alarms, enforcing the system pending-limit by
    /// keeping the earliest-firing triggers when the total would exceed the
    /// budget. Repeating (weekly) triggers are always retained because they
    /// cover unbounded future occurrences with a single slot; non-repeating
    /// triggers are trimmed from the far future first.
    public func triggers(
        for alarms: [Alarm],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = AlarmTriggerPlanner.systemPendingLimit
    ) -> [ScheduledTrigger] {
        let all = alarms.flatMap { triggers(for: $0, now: now, calendar: calendar) }
        guard all.count > limit else { return all }

        let repeating = all.filter { $0.repeats }
        let nonRepeating = all.filter { !$0.repeats }

        // Keep all repeating triggers; fill remaining budget with the soonest
        // non-repeating ones.
        let remaining = max(0, limit - repeating.count)
        let keptNonRepeating = nonRepeating
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
            .prefix(remaining)

        return repeating + Array(keptNonRepeating)
    }
}
