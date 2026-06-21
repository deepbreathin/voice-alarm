import SwiftUI
import UIKit
import UserNotifications

@main
struct VoiceAlarmApp: App {
    @StateObject private var model = AppModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    appDelegate.model = model
                    await model.bootstrap()
                }
                .onOpenURL { url in
                    model.handleOpenURL(url)
                }
        }
    }
}

/// Bridges UIKit notification callbacks into `AppModel`. Set as the
/// `UNUserNotificationCenter` delegate so alarms can present in-foreground and
/// taps can trigger full-clip playback.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var model: AppModel?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show the banner + play sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Handle taps: play the full recording.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmIDString = response.notification.request.content.userInfo[NotificationService.alarmIDKey] as? String
        Task { @MainActor in
            self.model?.handleNotificationTap(alarmIDString: alarmIDString)
            completionHandler()
        }
    }
}
