import SwiftUI
import UIKit
import CoreSpotlight
import UserNotifications

@main
struct ConfessionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StudyStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
                .onOpenURL { url in
                    // confession1689://today, confession1689://c11p1, …
                    store.destination = url.host ?? url.lastPathComponent
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // https://1689.intentmesh.dev/p/c11p1
                    guard let url = activity.webpageURL else { return }
                    let id = url.lastPathComponent
                    if !id.isEmpty, id != "p" { store.destination = id }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    store.adoptPendingBookmarks()
                    store.syncWithCloud()
                    store.publishToWidget()
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        store.destination = id
                    }
                }
                .task {
                    if let pending = QuickActionRelay.pending {
                        QuickActionRelay.pending = nil
                        store.destination = pending
                    }
                    ReaderTips.configure()
                    SyncStore.shared.start { StudyStore.shared.syncWithCloud() }
                    store.syncWithCloud()
                    SpotlightIndexer.indexIfNeeded()
                    if store.reminderEnabled {
                        await ReminderCenter.reschedule(hour: store.reminderHour,
                                                        minute: store.reminderMinute)
                    }
                    #if DEBUG
                    Library.shared.assertProofIntegrity()
                    #endif
                }
        }
        .commands { ReaderCommands(store: store) }
    }
}

// MARK: - Home-screen quick actions

enum QuickActionRelay {
    static var pending: String?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let destination = response.notification.request.content.userInfo["destination"] as? String
        Task { @MainActor in
            StudyStore.shared.destination = destination ?? "today"
        }
        completionHandler()
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            QuickActionRelay.pending = shortcut.type
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            StudyStore.shared.destination = shortcutItem.type
        }
        completionHandler(true)
    }
}

#if DEBUG
extension Library {
    /// Every proof reference on every paragraph must resolve to bundled verses.
    func assertProofIntegrity() {
        var missing: [String] = []
        for chapter in confession.chapters {
            for paragraph in chapter.paragraphs {
                for ref in paragraph.proofRefs where verses(for: ref) == nil {
                    missing.append(ref)
                }
            }
        }
        assert(missing.isEmpty, "Unresolvable proof refs: \(missing)")
    }
}
#endif
