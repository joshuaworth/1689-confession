import SwiftUI
import UIKit
import CoreSpotlight

@main
struct ConfessionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    SpotlightIndexer.indexIfNeeded()
                    #if DEBUG
                    Library.shared.assertProofIntegrity()
                    #endif
                }
        }
    }
}

// MARK: - Home-screen quick actions

enum QuickActionRelay {
    static var pending: String?
}

final class AppDelegate: NSObject, UIApplicationDelegate {
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
