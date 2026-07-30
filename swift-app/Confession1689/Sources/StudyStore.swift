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

    /// A query queued by the Siri search intent, consumed when the search opens.
    var pendingSearchQuery: String?

    @Published var recentSearches: [String] { didSet { defaults.set(recentSearches, forKey: "recents") } }
    @Published var hasLaunched: Bool { didSet { defaults.set(hasLaunched, forKey: "launched") } }

    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2 else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 6 { recentSearches = Array(recentSearches.prefix(6)) }
    }

    @Published var reminderEnabled: Bool { didSet { defaults.set(reminderEnabled, forKey: "remindOn") } }
    @Published var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: "remindHour") } }
    @Published var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: "remindMin") } }
    /// yyyy-MM-dd days on which today's reading was opened; drives the streak.
    @Published var readDays: [String] { didSet { defaults.set(readDays, forKey: "readDays") } }

    func recordTodayRead() {
        let key = Self.dayKey(Date())
        if !readDays.contains(key) { readDays.append(key) }
    }

    /// Consecutive days ending today (or yesterday, so an unopened morning doesn't zero it).
    var streak: Int {
        let set = Set(readDays)
        let calendar = Calendar.current
        var anchor = Date()
        if !set.contains(Self.dayKey(anchor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: anchor),
                  set.contains(Self.dayKey(yesterday)) else { return 0 }
            anchor = yesterday
        }
        var count = 0
        var cursor = anchor
        while set.contains(Self.dayKey(cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private static func dayKey(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }

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
        reminderEnabled = defaults.bool(forKey: "remindOn")
        reminderHour = defaults.object(forKey: "remindHour") as? Int ?? 8
        reminderMinute = defaults.object(forKey: "remindMin") as? Int ?? 0
        readDays = defaults.stringArray(forKey: "readDays") ?? []
        recentSearches = defaults.stringArray(forKey: "recents") ?? []
        hasLaunched = defaults.bool(forKey: "launched")
    }

    func toggleBookmark(_ id: String) {
        let adding: Bool
        if let index = bookmarks.firstIndex(of: id) { bookmarks.remove(at: index); adding = false }
        else { bookmarks.append(id); adding = true }
        SyncStore.shared.recordBookmark(id, added: adding)
    }

    func setNote(_ text: String?, for id: String) {
        if let text, !text.isEmpty { notes[id] = text } else { notes.removeValue(forKey: id) }
        SyncStore.shared.recordNote(id, text: text?.isEmpty == true ? nil : text)
    }

    /// Bookmarks made from the widget land in the shared container; adopt them.
    func adoptPendingBookmarks() {
        guard let shared = UserDefaults(suiteName: "group.com.intentmesh.confession1689"),
              let pending = shared.stringArray(forKey: "pendingBookmarks"), !pending.isEmpty
        else { return }
        for id in pending where !bookmarks.contains(id) {
            bookmarks.append(id)
            SyncStore.shared.recordBookmark(id, added: true)
        }
        shared.removeObject(forKey: "pendingBookmarks")
    }

    /// Values the widget shows but cannot compute for itself.
    func publishToWidget() {
        guard let shared = UserDefaults(suiteName: "group.com.intentmesh.confession1689") else { return }
        shared.set(streak, forKey: "streak")
    }

    /// Folds iCloud state in and pushes local-only records back up.
    func syncWithCloud() {
        let merged = SyncStore.shared.merge(localBookmarks: bookmarks, localNotes: notes)
        if merged.bookmarks != bookmarks.sorted() { bookmarks = merged.bookmarks }
        if merged.notes != notes { notes = merged.notes }
    }

    func isBookmarked(_ id: String) -> Bool { bookmarks.contains(id) }

    /// Reading sizes matching the site's five steps.
    var bodySize: CGFloat { [16.5, 18.5, 21, 24, 27][max(0, min(4, fontStep))] }

    /// The five steps are the reader's own choice, but a reader who has set a
    /// system text size larger than default means it — scale with them, and
    /// keep scaling into the accessibility sizes rather than stopping short.
    func bodySize(for category: ContentSizeCategory) -> CGFloat {
        let multiplier: CGFloat
        switch category {
        case .extraSmall: multiplier = 0.85
        case .small: multiplier = 0.9
        case .medium: multiplier = 0.95
        case .large: multiplier = 1.0
        case .extraLarge: multiplier = 1.08
        case .extraExtraLarge: multiplier = 1.16
        case .extraExtraExtraLarge: multiplier = 1.24
        case .accessibilityMedium: multiplier = 1.4
        case .accessibilityLarge: multiplier = 1.6
        case .accessibilityExtraLarge: multiplier = 1.85
        case .accessibilityExtraExtraLarge: multiplier = 2.1
        case .accessibilityExtraExtraExtraLarge: multiplier = 2.4
        @unknown default: multiplier = 1.0
        }
        return bodySize * multiplier
    }

    var colorScheme: ColorScheme? {
        guard let dark = darkOverride else { return nil }
        return dark ? .dark : .light
    }
}
