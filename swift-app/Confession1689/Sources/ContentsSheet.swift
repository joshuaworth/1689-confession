import SwiftUI

struct ContentsSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let scrollTo: (String) -> Void

    private let library = Library.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
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
                .padding(.bottom, 10)

                controls
                    .padding(.bottom, 26)

                if !store.bookmarks.isEmpty {
                    sectionHeader("Bookmarks")
                    ForEach(orderedBookmarks, id: \.self) { id in
                        bookmarkRow(id)
                    }
                    .padding(.bottom, 6)
                }

                sectionHeader("Contents")
                contentsRow(label: "Preface · 1677", sub: library.apparatus.preface.title, id: "preface")
                contentsRow(label: "Appendix", sub: library.apparatus.appendix.title, id: "appendix")
                ForEach(library.confession.chapters) { chapter in
                    chapterRow(chapter)
                }
                contentsRow(label: "Signatories", sub: "The Ministers and Messengers", id: "signatories")
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 50)
        }
        .background(Theme.paper(scheme).ignoresSafeArea())
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            segmented(Translation.allCases.map(\.label),
                      selected: Translation.allCases.firstIndex(of: store.translation) ?? 0) { index in
                store.translation = Translation.allCases[index]
            }

            segmented(["A", "A", "A", "A", "A"], sizes: [11, 13, 15, 17, 19],
                      selected: store.fontStep) { index in
                store.fontStep = index
            }

            HStack(spacing: 8) {
                toggleChip("Scripture Proofs", isOn: store.showProofs) { store.showProofs.toggle() }
                toggleChip("Candlelight", isOn: scheme == .dark) {
                    store.darkOverride = !(scheme == .dark)
                }
            }
        }
    }

    private func segmented(_ labels: [String], sizes: [CGFloat]? = nil,
                           selected: Int, tap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 3) {
            ForEach(labels.indices, id: \.self) { index in
                Button {
                    tap(index)
                } label: {
                    Text(labels[index])
                        .font(Fonts.sans(sizes?[index] ?? 12.5, weight: 600))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(index == selected ? Theme.red : .clear)
                        .foregroundColor(index == selected ? .white : Theme.inkSoft(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.paperDeep(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toggleChip(_ label: String, isOn: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(label)
                .font(Fonts.sans(13, weight: 500))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(isOn ? Theme.red : .clear)
                .foregroundColor(isOn ? .white : Theme.inkSoft(scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOn ? Theme.red : Theme.rule(scheme), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rows

    private var orderedBookmarks: [String] {
        let order = library.paragraphOrder
        return store.bookmarks.sorted { a, b in
            (order.firstIndex(of: a) ?? .max) < (order.firstIndex(of: b) ?? .max)
        }
    }

    private func bookmarkRow(_ id: String) -> some View {
        Button { scrollTo(id) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(library.label(for: id))
                    .font(Fonts.sans(12, weight: 600))
                    .foregroundColor(Theme.red)
                if let found = library.paragraph(for: id) {
                    Text(found.paragraph.text)
                        .font(Fonts.serif(14))
                        .foregroundColor(Theme.inkSoft(scheme))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(Fonts.sans(11, weight: 600))
            .kerning(1.5)
            .textCase(.uppercase)
            .foregroundColor(Theme.inkSoft(scheme))
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        Button { scrollTo("ch\(chapter.number)") } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(chapter.roman)
                    .font(Fonts.sans(12, weight: 600))
                    .foregroundColor(Theme.red)
                    .frame(width: 34, alignment: .leading)
                Text(chapter.title)
                    .font(Fonts.sans(15.5))
                    .foregroundColor(Theme.ink(scheme))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func contentsRow(label: String, sub: String, id: String) -> some View {
        Button { scrollTo(id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Fonts.sans(12, weight: 600))
                    .foregroundColor(Theme.red)
                Text(sub)
                    .font(Fonts.sans(15.5))
                    .foregroundColor(Theme.ink(scheme))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
