import UIKit
import StoreKit

/// Asked once, and only after the app has actually been useful: a reader who
/// has kept a streak of several days and written or saved something. Never on
/// launch, never mid-reading, never twice.
enum ReviewPrompt {
    private static let askedKey = "reviewAsked.v1"

    @MainActor
    static func considerAsking(streak: Int, bookmarks: Int, notes: Int) {
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return }
        guard streak >= 3, bookmarks + notes >= 2 else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        UserDefaults.standard.set(true, forKey: askedKey)
        // A beat after the moment that earned it, so it never interrupts a tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            AppStore.requestReview(in: scene)
        }
    }
}
