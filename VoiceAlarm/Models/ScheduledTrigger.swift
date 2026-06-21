import Foundation

/// A platform-agnostic description of a single notification that should be
/// scheduled. The iOS adapter (`NotificationScheduler`) converts each of these
/// into a `UNNotificationRequest`. Keeping this as a plain value type lets the
/// scheduling *decisions* be unit-tested without touching `UserNotifications`.
public struct ScheduledTrigger: Equatable, Hashable, Sendable {
    /// Stable, unique notification identifier.
    public let id: String
    /// Identifier of the owning alarm (used to cancel all of an alarm's
    /// triggers as a group).
    public let alarmID: UUID
    /// Date components describing when to fire. For repeating triggers only the
    /// recurring fields (e.g. weekday/hour/minute) are populated.
    public let dateComponents: DateComponents
    /// Whether iOS should repeat this trigger on its own.
    public let repeats: Bool
    /// The concrete fire date this trigger represents, when known (non-repeating
    /// triggers). Useful for display and for choosing a re-arm time. Repeating
    /// triggers leave this `nil`.
    public let fireDate: Date?

    public init(
        id: String,
        alarmID: UUID,
        dateComponents: DateComponents,
        repeats: Bool,
        fireDate: Date?
    ) {
        self.id = id
        self.alarmID = alarmID
        self.dateComponents = dateComponents
        self.repeats = repeats
        self.fireDate = fireDate
    }
}
