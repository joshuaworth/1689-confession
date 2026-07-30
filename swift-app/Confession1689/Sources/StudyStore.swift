import SwiftUI

/// Bookmarks, notes, reading position, and settings. Everything stays on device.
@MainActor
final class StudyStore: ObservableObject {
    static let shared = StudyStore()
    private let defaults = UserDefaults.standard

    @Published var bookmarks: [String] { didSet { defaults.set(bookmarks, forKey: "bm") } }
    @Published var notes: [String: String] { didSet { defaults.set(notes, forKey: "nt") } }
    @Published var fontStep: Int { didSet { defaults.set(fontStep, forKey: "fs") } }
    @Published var translation: Translation { didSet { defaults.set(translation.rawValue, forKey: "tr") } }
    @Published var showProofs: Bool { didSet { defaults.set(showProofs, forKey: "proofs") } }
    /// nil = follow the system; true = candlelight (dark); false = light.
    @Published var darkOverride: Bool? {
        didSet {
            if let value = darkOverride { defaults.set(value, forKey: "theme") }
            else { defaults.removeObject(forKey: "theme") }
        }
    }
    @Published var position: String? { didSet { defaults.set(position, forKey: "pos") } }
    /// True while the launch scroll-restore is in flight; paragraph onAppear must not record.
    var restoring = true

    /// Cross-entry navigation requests: "today", "search", "bookmarks", or a paragraph id.
    /// Set by widget taps, Spotlight results, and home-screen quick actions.
    @Published var destination: String?

    func recordPosition(_ id: String) {
        guard !restoring else { return }
        position = id
    }

    private init() {
        bookmarks = defaults.stringArray(forKey: "bm") ?? []
        notes = (defaults.dictionary(forKey: "nt") as? [String: String]) ?? [:]
        fontStep = defaults.object(forKey: "fs") as? Int ?? 1
        translation = Translation(rawValue: defaults.string(forKey: "tr") ?? "b") ?? .bsb
        showProofs = defaults.object(forKey: "proofs") as? Bool ?? true
        darkOverride = defaults.object(forKey: "theme") as? Bool
        position = defaults.string(forKey: "pos")
    }

    func toggleBookmark(_ id: String) {
        if let index = bookmarks.firstIndex(of: id) { bookmarks.remove(at: index) }
        else { bookmarks.append(id) }
    }

    func isBookmarked(_ id: String) -> Bool { bookmarks.contains(id) }

    /// Reading sizes matching the site's five steps.
    var bodySize: CGFloat { [16.5, 18.5, 21, 24, 27][max(0, min(4, fontStep))] }

    var colorScheme: ColorScheme? {
        guard let dark = darkOverride else { return nil }
        return dark ? .dark : .light
    }
}
