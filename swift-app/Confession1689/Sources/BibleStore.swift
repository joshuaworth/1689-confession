import Foundation

/// The complete Berean Standard Bible, bundled. Loaded off the main thread on
/// first use; every proof can open into its whole chapter, fully offline.
actor BibleStore {
    static let shared = BibleStore()

    /// "Book Chapter" -> ordered [verseNumber, text]
    private var chapters: [String: [[String]]]?

    private func load() -> [String: [[String]]] {
        if let chapters { return chapters }
        guard let url = Bundle.main.url(forResource: "bible-bsb", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [[String]]].self, from: data) else {
            chapters = [:]
            return [:]
        }
        chapters = decoded
        return decoded
    }

    /// Accepts "Psalms 19" and "Psalm 19" alike.
    func chapter(book: String, number: Int) -> [(verse: String, text: String)] {
        let all = load()
        let candidates = [book, book == "Psalms" ? "Psalm" : book]
        for name in candidates {
            if let rows = all["\(name) \(number)"] {
                return rows.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
            }
        }
        return []
    }
}

/// Parses "2 Timothy 3:15-17" / "Luke 16:29, 31" into chapter context + cited verse numbers.
struct ProofReference: Identifiable {
    var id: String { "\(book) \(chapter)" }
    let book: String
    let chapter: Int
    let citedVerses: Set<Int>
    var title: String { "\(book) \(chapter)" }

    init?(_ ref: String) {
        guard let match = ref.wholeMatch(of: #/(.+?)\s+(\d+):([\d\s,\-–]+)/#),
              let chapterNumber = Int(match.2) else { return nil }
        book = String(match.1).trimmingCharacters(in: .whitespaces)
        chapter = chapterNumber
        var cited = Set<Int>()
        for part in match.3.split(separator: ",") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            let bounds = piece.split(whereSeparator: { $0 == "-" || $0 == "\u{2013}" })
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if bounds.count == 2, bounds[0] <= bounds[1] {
                cited.formUnion(bounds[0]...bounds[1])
            } else if let single = bounds.first {
                cited.insert(single)
            }
        }
        citedVerses = cited
    }
}
