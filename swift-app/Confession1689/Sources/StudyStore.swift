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
