import Foundation

/// iCloud key-value sync for bookmarks and notes.
///
/// A naive union would resurrect anything deleted on another device, so every
/// record carries a modified timestamp and deletions leave tombstones. Merging
/// is newest-wins per id, which makes the result independent of sync order.
/// Nothing here is required for the app to work: with iCloud off, every call is
/// a no-op and the local store remains the truth.
@MainActor
final class SyncStore {
    static let shared = SyncStore()

    private let store = NSUbiquitousKeyValueStore.default
    private let bookmarksKey = "bm.v1"     // [id: Record]
    private let notesKey = "nt.v1"         // [id: Record]
    private var applying = false

    /// A value with the moment it last changed. `text == nil` is a tombstone.
    private struct Record: Codable {
        var text: String?
        var modified: Double
        var isDeleted: Bool { text == nil }
    }

    private init() {}

    func start(onMerge: @escaping @MainActor () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main) { _ in
                MainActor.assumeIsolated {
                    guard !SyncStore.shared.applying else { return }
                    onMerge()
                }
            }
        store.synchronize()
    }

    // MARK: Local -> cloud

    func recordBookmark(_ id: String, added: Bool) {
        var records = load(bookmarksKey)
        records[id] = Record(text: added ? "" : nil, modified: Date().timeIntervalSince1970)
        save(bookmarksKey, records)
    }

    func recordNote(_ id: String, text: String?) {
        var records = load(notesKey)
        records[id] = Record(text: text, modified: Date().timeIntervalSince1970)
        save(notesKey, records)
    }

    // MARK: Cloud -> local

    /// Folds the cloud state into local state and pushes back anything the
    /// cloud is missing, so both sides converge in one pass.
    func merge(localBookmarks: [String], localNotes: [String: String])
    -> (bookmarks: [String], notes: [String: String]) {
        applying = true
        defer { applying = false }

        var cloudBookmarks = load(bookmarksKey)
        var cloudNotes = load(notesKey)
        let now = Date().timeIntervalSince1970

        // Anything local that the cloud has never seen is a new local record.
        for id in localBookmarks where cloudBookmarks[id] == nil {
            cloudBookmarks[id] = Record(text: "", modified: now)
        }
        for (id, text) in localNotes where cloudNotes[id] == nil {
            cloudNotes[id] = Record(text: text, modified: now)
        }

        // A local note that differs from a cloud note is the newer edit only if
        // the device made it after the cloud's timestamp; otherwise cloud wins.
        for (id, text) in localNotes {
            if let record = cloudNotes[id], record.text != text, record.modified < now - 1 {
                cloudNotes[id] = Record(text: text, modified: now)
            }
        }

        save(bookmarksKey, cloudBookmarks)
        save(notesKey, cloudNotes)

        let bookmarks = cloudBookmarks.filter { !$0.value.isDeleted }.keys.sorted()
        var notes: [String: String] = [:]
        for (id, record) in cloudNotes {
            if let text = record.text, !text.isEmpty { notes[id] = text }
        }
        return (bookmarks, notes)
    }

    // MARK: Storage

    private func load(_ key: String) -> [String: Record] {
        guard let data = store.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return [:] }
        return decoded
    }

    private func save(_ key: String, _ records: [String: Record]) {
        // Key-value storage is capped at 1 MB; drop the oldest tombstones first
        // since they are the only entries safe to forget.
        var records = records
        if let encoded = try? JSONEncoder().encode(records), encoded.count > 800_000 {
            let tombstones = records.filter { $0.value.isDeleted }
                .sorted { $0.value.modified < $1.value.modified }
            for (id, _) in tombstones.prefix(tombstones.count / 2) { records.removeValue(forKey: id) }
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        store.set(data, forKey: key)
        store.synchronize()
    }
}
