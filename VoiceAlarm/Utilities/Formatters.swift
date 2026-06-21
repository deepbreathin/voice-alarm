import Foundation

/// Centralised, locale-aware formatting helpers. Kept pure (calendar/locale are
/// injectable) so display strings can be unit-tested deterministically.
public enum Formatters {

    /// Formats a clip length as `m:ss` (or `h:mm:ss` for long clips).
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Formats a `TimeOfDay` honouring the locale's 12/24-hour preference.
    public static func time(_ time: TimeOfDay, locale: Locale = .current, calendar: Calendar = .current) -> String {
        var cal = calendar
        cal.locale = locale
        let date = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = cal
        formatter.timeZone = cal.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// A human-readable description of a recurrence, e.g.
    /// "Once on Jun 24", "Weekdays", "Mon, Wed, Fri", "Every 3 days".
    public static func recurrenceDescription(
        _ recurrence: Recurrence,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        switch recurrence {
        case .oneOff(let day):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            return "Once on \(formatter.string(from: day))"

        case .weekly(let days):
            if days.isEmpty { return "Never" }
            if days == Weekday.everyDay { return "Every day" }
            if days == Weekday.weekdays { return "Weekdays" }
            if days == Weekday.weekend { return "Weekends" }
            let ordered = Weekday.mondayFirstOrder.filter { days.contains($0) }
            return ordered.map { $0.shortSymbol(calendar: calendar) }.joined(separator: ", ")

        case .everyNDays(let interval, _):
            let n = max(1, interval)
            return n == 1 ? "Every day" : "Every \(n) days"
        }
    }

    /// A relative description of when an alarm next fires, e.g.
    /// "Today at 7:00 AM", "Tomorrow at 6:30 AM", "Mon, Jun 23 at 9:00 AM".
    public static func nextFireDescription(
        _ date: Date,
        now: Date = Date(),
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let timeString = timeFormatter.string(from: date)

        // Compute Today/Tomorrow relative to the supplied `now` (not the system
        // clock) so the result is deterministic and testable.
        let dayDiff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if dayDiff == 0 { return "Today at \(timeString)" }
        if dayDiff == 1 { return "Tomorrow at \(timeString)" }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return "\(dateFormatter.string(from: date)) at \(timeString)"
    }
}
