import Foundation

// MARK: - Confession text

struct Confession: Decodable {
    let title: String
    let chapters: [Chapter]
}

struct Chapter: Decodable, Identifiable {
    let number: Int
    let title: String
    let paragraphs: [Paragraph]
    var id: Int { number }

    var roman: String { Roman.numeral(number) }
}

struct Paragraph: Decodable {
    let number: Int
    let text: String
    let proofs: String

    var proofRefs: [String] {
        proofs.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

// MARK: - Apparatus

struct Apparatus: Decodable {
    let preface: Section
    let appendix: Section
    let signatories: Signatories

    struct Section: Decodable {
        let title: String
        let paragraphs: [String]
    }

    struct Signatories: Decodable {
        let title: String
        let note: String
        let names: [Signer]
        let subscription: String
    }

    struct Signer: Decodable, Identifiable {
        let name: String
        let role: String?
        let church: String?
        var id: String { name + (church ?? "") }
    }
}

// MARK: - Verses

struct Verse: Decodable {
    let r: String
    let b: String?
    let k: String?
    let w: String?

    func text(for translation: Translation) -> String? {
        switch translation {
        case .bsb: return b
        case .kjv: return k
        case .web: return w
        case .parallel: return b ?? k ?? w
        }
    }
}

enum Translation: String, CaseIterable, Identifiable {
    case bsb = "b", kjv = "k", web = "w", parallel = "p"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bsb: return "BSB"
        case .kjv: return "KJV"
        case .web: return "WEB"
        case .parallel: return "Parallel"
        }
    }
}

// MARK: - Library (bundled data, loaded once)

final class Library {
    static let shared = Library()

    let confession: Confession
    let apparatus: Apparatus
    let verses: [String: [Verse]]

    /// Every confession paragraph id in document order, e.g. "c1p1".
    let paragraphOrder: [String]

    private init() {
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                fatalError("Missing bundled resource \(name).json")
            }
            return value
        }
        confession = load("confession", as: Confession.self)
        apparatus = load("apparatus", as: Apparatus.self)
        verses = load("verses", as: [String: [Verse]].self)
        paragraphOrder = confession.chapters.flatMap { ch in
            ch.paragraphs.map { "c\(ch.number)p\($0.number)" }
        }
    }

    func verses(for ref: String) -> [Verse]? { verses[ref] }

    /// Deterministic daily paragraph: same for everyone, everywhere.
    func todayParagraphID(date: Date = Date()) -> String {
        let days = Int(date.timeIntervalSince1970 / 86_400)
        return paragraphOrder[days % paragraphOrder.count]
    }

    func paragraph(for id: String) -> (chapter: Chapter, paragraph: Paragraph)? {
        guard let match = id.wholeMatch(of: #/c(\d+)p(\d+)/#),
              let ch = confession.chapters.first(where: { $0.number == Int(match.1)! }),
              let p = ch.paragraphs.first(where: { $0.number == Int(match.2)! }) else { return nil }
        return (ch, p)
    }

    func label(for id: String) -> String {
        guard let found = paragraph(for: id) else { return id }
        return "Chapter \(found.chapter.roman) · ¶ \(found.paragraph.number)"
    }
}

// MARK: - Roman numerals

enum Roman {
    static func numeral(_ n: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                                      (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (value, glyph) in table {
            while n >= value { out += glyph; n -= value }
        }
        return out
    }
}
