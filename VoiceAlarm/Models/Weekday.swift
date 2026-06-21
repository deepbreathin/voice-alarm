import Foundation

/// A day of the week.
///
/// Raw values intentionally match Apple's `Calendar` weekday numbering
/// (1 = Sunday ... 7 = Saturday). This makes it trivial to translate a
/// `Weekday` into the `weekday` field of `DateComponents` when building
/// notification triggers, with no off-by-one conversions.
public enum Weekday: Int, CaseIterable, Codable, Identifiable, Sendable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var id: Int { rawValue }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Weekdays ordered Monday → Sunday, which is the order most people
    /// expect to see in an alarm UI.
    public static let mondayFirstOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    /// The Monday–Friday work week.
    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Saturday and Sunday.
    public static let weekend: Set<Weekday> = [.saturday, .sunday]

    /// Every day of the week.
    public static let everyDay: Set<Weekday> = Set(Weekday.allCases)

    /// A locale-aware short symbol such as "Mon" (uses the current calendar's
    /// short standalone weekday symbols). A `calendar`/`locale` may be injected
    /// for deterministic testing.
    public func shortSymbol(calendar: Calendar = .current) -> String {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        // `shortStandaloneWeekdaySymbols` is indexed 0 = Sunday ... 6 = Saturday.
        let index = rawValue - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    /// A locale-aware full symbol such as "Monday".
    public func fullSymbol(calendar: Calendar = .current) -> String {
        let symbols = calendar.standaloneWeekdaySymbols
        let index = rawValue - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}
