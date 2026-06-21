import Foundation

/// A wall-clock time of day (hour + minute) independent of any particular
/// calendar date. Used as the "fire time" for alarms.
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        // Clamp into valid ranges so a malformed value can never produce an
        // un-schedulable notification trigger.
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Builds a `TimeOfDay` from a concrete `Date` using the given calendar.
    public init(date: Date, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }

    /// Minutes since midnight — convenient for comparisons.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// Returns the concrete `Date` on the same calendar day as `day` whose
    /// time-of-day equals this value.
    public func applied(to day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
