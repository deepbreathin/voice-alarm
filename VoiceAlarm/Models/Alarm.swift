import Foundation

/// A scheduled alarm: at `time`, according to `recurrence`, play `recordingID`.
public struct Alarm: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    /// The recording to play. May be `nil` if the recording was deleted; such
    /// an alarm is treated as not schedulable until a clip is re-assigned.
    public var recordingID: UUID?
    public var time: TimeOfDay
    public var recurrence: Recurrence
    public var isEnabled: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        label: String = "",
        recordingID: UUID?,
        time: TimeOfDay,
        recurrence: Recurrence,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.recordingID = recordingID
        self.time = time
        self.recurrence = recurrence
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    /// Whether this alarm is in a state where it could actually fire.
    ///
    /// Requires it to be enabled, have a recording assigned, and have a
    /// recurrence that produces at least one occurrence (a one-off, or a
    /// repeating pattern with at least one selected day).
    public var isSchedulable: Bool {
        guard isEnabled, recordingID != nil else { return false }
        switch recurrence {
        case .oneOff:
            return true
        case .weekly(let days):
            return !days.isEmpty
        case .everyNDays:
            return true
        }
    }

    /// The next time this alarm will fire after `now`, or `nil` if never.
    public func nextFireDate(after now: Date, calendar: Calendar = .current) -> Date? {
        guard isEnabled, recordingID != nil else { return nil }
        return recurrence.nextOccurrence(after: now, at: time, calendar: calendar)
    }
}
