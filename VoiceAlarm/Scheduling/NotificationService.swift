import Foundation
import Combine
import UserNotifications

/// iOS adapter that registers `ScheduledTrigger`s as real local notifications
/// and manages authorization. The *decisions* about what to schedule live in
/// the pure `AlarmTriggerPlanner`; this type only performs the side effects.
@MainActor
public final class NotificationService: ObservableObject {

    public static let categoryIdentifier = "VOICE_ALARM"
    /// Userinfo key carrying the originating alarm id, so the app can play the
    /// full clip when launched from a notification tap.
    public static let alarmIDKey = "alarmID"

    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Registers the notification category used by all alarms.
    public func registerCategories() {
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    public func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests alert + sound authorization. Returns whether granted.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    /// Replaces all pending alarm notifications with the supplied triggers.
    ///
    /// - Parameters:
    ///   - triggers: the desired pending notifications (from the planner).
    ///   - title: notification title (typically the alarm label).
    ///   - soundForAlarm: maps an alarm id to its prepared ≤30s sound file
    ///     name; `nil` falls back to the default notification sound.
    public func reschedule(
        triggers: [ScheduledTrigger],
        titleForAlarm: @escaping (UUID) -> String,
        soundForAlarm: @escaping (UUID) -> String?
    ) async {
        // Clear everything we own, then add the new set. Simpler and less
        // error-prone than diffing, and well within the 64-request budget.
        center.removeAllPendingNotificationRequests()

        for trigger in triggers {
            let content = UNMutableNotificationContent()
            let label = titleForAlarm(trigger.alarmID)
            content.title = label.isEmpty ? "Voice Alarm" : label
            content.body = "Tap to play your recording."
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = [Self.alarmIDKey: trigger.alarmID.uuidString]
            if let soundName = soundForAlarm(trigger.alarmID) {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            } else {
                content.sound = .default
            }

            let calTrigger = UNCalendarNotificationTrigger(
                dateMatching: trigger.dateComponents,
                repeats: trigger.repeats
            )
            let request = UNNotificationRequest(
                identifier: trigger.id,
                content: content,
                trigger: calTrigger
            )
            try? await center.add(request)
        }
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    public func pendingIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}
