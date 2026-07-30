import SwiftUI

/// A whole Bible chapter, opened from a scripture proof, cited verses marked.
struct BibleChapterSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let reference: ProofReference
    @State private var verses: [(verse: String, text: String)] = []

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
                            Text(reference.title)
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
                    .padding(.bottom, 22)

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
                verses = await BibleStore.shared.chapter(book: reference.book, number: reference.chapter)
                if let first = reference.citedVerses.min() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo("v\(first)", anchor: .center)
                    }
                }
            }
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
