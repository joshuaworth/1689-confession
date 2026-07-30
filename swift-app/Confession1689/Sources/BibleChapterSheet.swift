import SwiftUI

/// A whole Bible chapter, opened from a scripture proof, cited verses marked.
struct BibleChapterSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let reference: ProofReference
    /// Where the citation came from, so the reader can step back into the confession.
    var citedIn: String?
    var jumpBack: ((String) -> Void)?

    @State private var verses: [(verse: String, text: String)] = []
    @State private var chapterNumber: Int = 0
    @State private var hasNext = false
    @State private var hasPrevious = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Berean Standard Bible")
                                .font(Fonts.sans(11, weight: 600))
                                .kerning(1.5)
                                .textCase(.uppercase)
                                .foregroundColor(Theme.red)
                            Text("\(reference.book) \(chapterNumber)")
                                .font(Fonts.serif(30, weight: 500))
                                .foregroundColor(Theme.red)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Text("✕")
                                .font(Fonts.sans(15, weight: 500))
                                .foregroundColor(Theme.ink(scheme))
                                .frame(width: 40, height: 40)
                                .background(Theme.paperDeep(scheme))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 26)
                    .padding(.bottom, 14)

                    HStack(spacing: 14) {
                        stepButton("‹", enabled: hasPrevious) { load(chapterNumber - 1, proxy: proxy) }
                        Text("Chapter \(chapterNumber)")
                            .font(Fonts.sans(12.5, weight: 600))
                            .monospacedDigit()
                            .foregroundColor(Theme.inkSoft(scheme))
                        stepButton("›", enabled: hasNext) { load(chapterNumber + 1, proxy: proxy) }
                        Spacer()
                    }
                    .padding(.bottom, 12)

                    if let citedIn, let jumpBack {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { jumpBack(citedIn) }
                        } label: {
                            Text("Cited in \(Library.shared.label(for: citedIn))  ↩")
                                .font(Fonts.sans(12, weight: 600))
                                .foregroundColor(Theme.red)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.red, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 18)
                    }

                    ForEach(verses, id: \.verse) { row in
                        verseView(row)
                            .id("v\(row.verse)")
                    }

                    Text("The Berean Standard Bible is in the public domain.")
                        .font(Fonts.sans(11))
                        .foregroundColor(Theme.inkSoft(scheme).opacity(0.75))
                        .padding(.top, 18)
                        .padding(.bottom, 50)
                }
                .padding(.horizontal, 20)
            }
            .background(Theme.paper(scheme).ignoresSafeArea())
            .task {
                chapterNumber = reference.chapter
                verses = await BibleStore.shared.chapter(book: reference.book, number: reference.chapter)
                await refreshNeighbors()
                if let first = reference.citedVerses.min() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo("v\(first)", anchor: .center)
                    }
                }
            }
        }
    }

    private func stepButton(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(Fonts.sans(17, weight: 600))
                .foregroundColor(enabled ? Theme.red : Theme.rule(scheme))
                .frame(width: 34, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(enabled ? Theme.red : Theme.rule(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(glyph == "‹" ? "Previous chapter" : "Next chapter")
    }

    private func load(_ number: Int, proxy: ScrollViewProxy) {
        guard number > 0 else { return }
        Task {
            let rows = await BibleStore.shared.chapter(book: reference.book, number: number)
            guard !rows.isEmpty else { return }
            await MainActor.run {
                Haptics.chapterBoundary()
                chapterNumber = number
                verses = rows
                proxy.scrollTo("v1", anchor: .top)
            }
            await refreshNeighbors()
        }
    }

    private func refreshNeighbors() async {
        let next = await BibleStore.shared.chapter(book: reference.book, number: chapterNumber + 1)
        let previous = chapterNumber > 1
            ? await BibleStore.shared.chapter(book: reference.book, number: chapterNumber - 1)
            : []
        await MainActor.run {
            hasNext = !next.isEmpty
            hasPrevious = !previous.isEmpty
        }
    }

    private func verseView(_ row: (verse: String, text: String)) -> some View {
        let cited = Int(row.verse).map { reference.citedVerses.contains($0) } ?? false
        var pnum = AttributedString("\(row.verse)  ")
        pnum.font = Fonts.sans(11.5, weight: 600)
        pnum.foregroundColor = cited ? Theme.red : Theme.inkSoft(scheme)
        var body = AttributedString(row.text)
        body.font = Fonts.serif(17.5)
        body.foregroundColor = Theme.ink(scheme)
        return Text(pnum + body)
            .monospacedDigit()
            .lineSpacing(8)
            .padding(.bottom, 10)
            .padding(.leading, cited ? 14 : 0)
            .overlay(alignment: .leading) {
                if cited {
                    Rectangle().fill(Theme.red).frame(width: 2)
                        .padding(.bottom, 10)
                }
            }
            .textSelection(.enabled)
    }
}
