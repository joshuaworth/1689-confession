import AppIntents
import WidgetKit

/// Bookmarking today's reading without opening the app. The widget writes
/// through the shared group container, which the app reads on next launch.
struct BookmarkTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Bookmark Today's Reading"
    static var description = IntentDescription("Bookmarks the paragraph shown on the widget.")

    func perform() async throws -> some IntentResult {
        guard let shared = UserDefaults(suiteName: "group.com.intentmesh.confession1689") else {
            return .result()
        }
        let id = WLibrary.todayID(for: Date())
        var pending = shared.stringArray(forKey: "pendingBookmarks") ?? []
        if !pending.contains(id) { pending.append(id) }
        shared.set(pending, forKey: "pendingBookmarks")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Opens the app at today's reading. Used by the Control Center control.
struct OpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Reading"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
