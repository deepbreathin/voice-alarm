import Foundation

/// Describes how often an alarm repeats.
///
/// Supports the three patterns the product requires:
/// - `.oneOff`     — fires a single time on a specific calendar day.
/// - `.weekly`     — fires on a chosen set of weekdays (Mon–Sun), every week.
/// - `.everyNDays` — fires every *N* days, counting from an anchor day.
///
/// "Custom" configurations are expressed through these cases (e.g. an arbitrary
/// subset of weekdays, or any interval such as every 3 days).
public enum Recurrence: Codable, Equatable, Hashable, Sendable {
    /// A single occurrence. `day` identifies the calendar day; the alarm's
    /// `TimeOfDay` supplies the time on that day.
    case oneOff(day: Date)

    /// Repeats weekly on the given weekdays. An empty set never fires.
    case weekly(days: Set<Weekday>)

    /// Repeats every `interval` days starting from `anchorDay`.
    /// `interval` is clamped to be at least 1.
    case everyNDays(interval: Int, anchorDay: Date)

    /// Whether this recurrence can ever fire more than once.
    public var isRepeating: Bool {
        switch self {
        case .oneOff: return false
        case .weekly(let days): return !days.isEmpty
        case .everyNDays: return true
        }
    }
}
