import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let scrollTo: (String) -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private let library = Library.shared

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Search the confession and its scripture proofs…", text: $query)
                        .font(Fonts.sans(17))
                        .foregroundColor(Theme.ink(scheme))
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .padding(.vertical, 17)
                        .padding(.leading, 14)
                    Button("esc") { dismiss() }
                        .font(Fonts.sans(11, weight: 500))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule(scheme)))
                        .foregroundColor(Theme.inkSoft(scheme))
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule(scheme)).frame(height: 1) }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let results = search(query)
                        if !query.isEmpty && query.count > 1 && results.isEmpty {
                            Text("Nothing found for \u{201C}\(query)\u{201D}")
                                .font(Fonts.sans(14))
                                .foregroundColor(Theme.inkSoft(scheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        }
                        let grouped = Dictionary(grouping: results, by: \.group)
                        ForEach(["Chapters", "In the Confession", "In the Scripture Proofs"], id: \.self) { group in
                            if let items = grouped[group], !items.isEmpty {
                                Text(group)
                                    .font(Fonts.sans(10.5, weight: 600))
                                    .kerning(1.2)
                                    .textCase(.uppercase)
                                    .foregroundColor(Theme.inkSoft(scheme))
                                    .padding(.horizontal, 18)
                                    .padding(.top, 14).padding(.bottom, 5)
                                ForEach(items) { resultRow($0) }
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: 420)
            }
            .background(Theme.paper(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.rule(scheme)))
            .shadow(color: .black.opacity(0.35), radius: 35, y: 24)
            .padding(.horizontal, 10)
            .padding(.top, 16)
        }
        .presentationBackground(.clear)
        .onAppear {
            focused = true
            #if DEBUG
            if let seeded = UserDefaults.standard.string(forKey: "seedSearchQuery") {
                query = seeded
            }
            #endif
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            scrollTo(result.targetID)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.where_)
                    .font(Fonts.sans(12, weight: 600))
                    .foregroundColor(Theme.red)
                Text(result.excerpt)
                    .font(Fonts.serif(15.5))
                    .lineSpacing(4)
                    .foregroundColor(Theme.inkSoft(scheme))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Search (port of the site's scorer)

    struct SearchResult: Identifiable {
        let id = UUID()
        let group: String
        let where_: String
        let excerpt: String
        let targetID: String
        let score: Double
    }

    private func search(_ raw: String) -> [SearchResult] {
        let phrase = normalize(raw)
        guard phrase.count >= 2 else { return [] }
        let terms = phrase.split(separator: " ").map(String.init).filter { $0.count > 1 }
        let needles = terms.isEmpty ? [phrase] : terms

        var results: [SearchResult] = []

        // Chapter jump: "chapter 11" / "ch 11" / bare number
        if let match = phrase.wholeMatch(of: #/(?:chapter|chap|ch)?\.?\s*(\d{1,2})/#),
           let n = Int(match.1), (1...32).contains(n),
           let chapter = library.confession.chapters.first(where: { $0.number == n }) {
            results.append(SearchResult(group: "Chapters",
                                        where_: "Chapter \(chapter.roman)",
                                        excerpt: chapter.title,
                                        targetID: "ch\(n)", score: 100))
        }

        // Confession + apparatus paragraphs
        var paragraphHits: [SearchResult] = []
        for chapter in library.confession.chapters {
            for paragraph in chapter.paragraphs {
                let score = scoreText(normalize(paragraph.text), needles: needles, phrase: phrase)
                if score > 0 {
                    paragraphHits.append(SearchResult(
                        group: "In the Confession",
                        where_: "Chapter \(chapter.roman) · ¶ \(paragraph.number) — \(chapter.title)",
                        excerpt: excerpt(paragraph.text, needles: needles),
                        targetID: "c\(chapter.number)p\(paragraph.number)",
                        score: score + 2))
                } else if scoreText(normalize(chapter.title), needles: needles, phrase: phrase) > 0,
                          paragraph.number == 1 {
                    paragraphHits.append(SearchResult(
                        group: "In the Confession",
                        where_: "Chapter \(chapter.roman) — \(chapter.title)",
                        excerpt: String(paragraph.text.prefix(190)),
                        targetID: "c\(chapter.number)p1",
                        score: 3))
                }
            }
        }
        for (prefix, section) in [("preface", library.apparatus.preface),
                                  ("appendix", library.apparatus.appendix)] {
            for (index, text) in section.paragraphs.enumerated() {
                let score = scoreText(normalize(text), needles: needles, phrase: phrase)
                if score > 0 {
                    paragraphHits.append(SearchResult(
                        group: "In the Confession",
                        where_: "\(section.title) · ¶ \(index + 1)",
                        excerpt: excerpt(text, needles: needles),
                        targetID: "\(prefix)-p\(index + 1)",
                        score: score + 1))
                }
            }
        }
        results += paragraphHits.sorted { $0.score > $1.score }.prefix(8)

        // Verses: ref-prefix queries and content matches, deduped
        var verseHits: [SearchResult] = []
        let isRefQuery = phrase.contains(where: \.isNumber)
        for (refKey, verses) in library.verses {
            for verse in verses {
                var score = 0.0
                var source = ""
                if isRefQuery && normalize(verse.r).hasPrefix(phrase) {
                    score = 50; source = verse.b ?? verse.k ?? verse.w ?? ""
                } else {
                    for (label, text) in [("BSB", verse.b), ("KJV", verse.k), ("WEB", verse.w)] {
                        guard let text else { continue }
                        let s = scoreText(normalize(text), needles: needles, phrase: phrase)
                        if s > 0 { score = s; source = "\(label)|\(text)"; break }
                    }
                }
                if score > 0 {
                    let parts = source.split(separator: "|", maxSplits: 1).map(String.init)
                    let badge = parts.count == 2 ? " · \(parts[0])" : ""
                    let text = parts.count == 2 ? parts[1] : source
                    if let target = targetParagraph(for: refKey) {
                        verseHits.append(SearchResult(
                            group: "In the Scripture Proofs",
                            where_: verse.r + badge,
                            excerpt: excerpt(text, needles: isRefQuery ? [] : needles),
                            targetID: target,
                            score: score))
                    }
                }
            }
        }
        var seen = Set<String>()
        let dedupedVerses = verseHits.sorted { $0.score > $1.score }.filter { hit in
            let key = hit.where_ + String(hit.excerpt.prefix(40))
            return seen.insert(key).inserted
        }
        results += dedupedVerses.prefix(10)
        return results
    }

    /// The paragraph that cites this reference, so tapping a verse lands in context.
    private func targetParagraph(for ref: String) -> String? {
        for chapter in library.confession.chapters {
            for paragraph in chapter.paragraphs where paragraph.proofRefs.contains(ref) {
                return "c\(chapter.number)p\(paragraph.number)"
            }
        }
        return nil
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .trimmingCharacters(in: .whitespaces)
    }

    private func scoreText(_ text: String, needles: [String], phrase: String) -> Double {
        var score = 0.0
        for needle in needles {
            guard text.contains(needle) else { return 0 }
            score += 1
            let extra = text.components(separatedBy: needle).count - 2
            score += Double(min(3, max(0, extra))) * 0.3
        }
        if text.contains(phrase) { score += 6 }
        return score
    }

    private func excerpt(_ text: String, needles: [String]) -> String {
        let normalized = normalize(text)
        guard let first = needles.first, let range = normalized.range(of: first) else {
            return String(text.prefix(190))
        }
        let offset = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let start = max(0, offset - 60)
        let slice = String(text.dropFirst(start).prefix(190))
        return (start > 0 ? "…" : "") + slice + (start + 190 < text.count ? "…" : "")
    }
}
