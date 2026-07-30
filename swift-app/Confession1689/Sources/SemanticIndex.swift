import Foundation
import NaturalLanguage

/// On-device semantic search over the confession: Apple's sentence embeddings,
/// computed once per launch in the background, cosine-matched against queries.
/// "assurance of salvation" finds Chapter XVIII even where the words differ.
final class SemanticIndex: @unchecked Sendable {
    static let shared = SemanticIndex()

    struct Entry {
        let targetID: String
        let where_: String
        let excerpt: String
        let vector: [Double]
    }

    private let queue = DispatchQueue(label: "semantic-index")
    private var entries: [Entry] = []
    private var embedding: NLEmbedding?
    private var built = false

    func buildIfNeeded() {
        queue.async { [self] in
            guard !built else { return }
            built = true
            guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else { return }
            embedding = sentenceEmbedding

            let library = Library.shared
            var result: [Entry] = []
            for chapter in library.confession.chapters {
                for paragraph in chapter.paragraphs {
                    let text = String(paragraph.text.prefix(500))
                    guard let vector = sentenceEmbedding.vector(for: text) else { continue }
                    result.append(Entry(
                        targetID: "c\(chapter.number)p\(paragraph.number)",
                        where_: "Chapter \(chapter.roman) · ¶ \(paragraph.number) — \(chapter.title)",
                        excerpt: String(paragraph.text.prefix(190)),
                        vector: vector))
                }
            }
            entries = result
        }
    }

    /// Top related paragraphs for a query, excluding ids already found lexically.
    func related(to query: String, excluding: Set<String>, limit: Int = 4) -> [(targetID: String, where_: String, excerpt: String)] {
        guard query.count > 3 else { return [] }
        return queue.sync { [self] in
            guard let embedding, !entries.isEmpty,
                  let queryVector = embedding.vector(for: query) else { return [] }
            let scored = entries.compactMap { entry -> (Entry, Double)? in
                guard !excluding.contains(entry.targetID) else { return nil }
                return (entry, cosine(queryVector, entry.vector))
            }
            return scored.sorted { $0.1 > $1.1 }
                .prefix(limit)
                .filter { $0.1 > 0.55 }
                .map { ($0.0.targetID, $0.0.where_, $0.0.excerpt) }
        }
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, magA = 0.0, magB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        let denominator = (magA.squareRoot() * magB.squareRoot())
        return denominator > 0 ? dot / denominator : 0
    }
}
