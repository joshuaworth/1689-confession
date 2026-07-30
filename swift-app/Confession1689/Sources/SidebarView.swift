import SwiftUI

/// The contents, permanently visible where there is room for it. Same material
/// as the mobile sheet, but resident rather than summoned — on iPad and Mac the
/// contents are a place you glance at, not a thing you open.
struct SidebarView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    let scrollTo: (String) -> Void
    let openNotes: () -> Void

    private let library = Library.shared

    var body: some View {
        List {
            Section {
                Button {
                    scrollTo(library.todayParagraphID())
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's Reading")
                            .font(Fonts.sans(10.5, weight: 600))
                            .kerning(1.3)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.inkSoft(scheme))
                        Text(library.label(for: library.todayParagraphID()))
                            .font(Fonts.sans(13.5, weight: 600))
                            .foregroundColor(Theme.red)
                    }
                }
                .buttonStyle(.plain)
            }

            if !store.bookmarks.isEmpty {
                Section("Bookmarks") {
                    ForEach(orderedBookmarks, id: \.self) { id in
                        Button { scrollTo(id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(library.label(for: id))
                                    .font(Fonts.sans(12, weight: 600))
                                    .foregroundColor(Theme.red)
                                if let found = library.paragraph(for: id) {
                                    Text(found.paragraph.text)
                                        .font(Fonts.serif(13))
                                        .foregroundColor(Theme.inkSoft(scheme))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Contents") {
                row(label: "Preface · 1677", sub: library.apparatus.preface.title, id: "preface")
                ForEach(library.confession.chapters) { chapter in
                    Button { scrollTo("ch\(chapter.number)") } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(chapter.roman)
                                .font(Fonts.sans(11.5, weight: 600))
                                .monospacedDigit()
                                .foregroundColor(Theme.red)
                                .frame(width: 34, alignment: .leading)
                            Text(chapter.title)
                                .font(Fonts.sans(14))
                                .foregroundColor(Theme.ink(scheme))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
                row(label: "Appendix · 1677", sub: library.apparatus.appendix.title, id: "appendix")
                row(label: "Signatories", sub: "The Ministers and Messengers", id: "signatories")
            }

            if !store.notes.isEmpty {
                Section {
                    Button("My Notes (\(store.notes.count))") { openNotes() }
                        .font(Fonts.sans(13, weight: 600))
                        .foregroundColor(Theme.red)
                        .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("1689.")
    }

    private var orderedBookmarks: [String] {
        let order = library.paragraphOrder
        return store.bookmarks.sorted {
            (order.firstIndex(of: $0) ?? .max) < (order.firstIndex(of: $1) ?? .max)
        }
    }

    private func row(label: String, sub: String, id: String) -> some View {
        Button { scrollTo(id) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Fonts.sans(11.5, weight: 600))
                    .foregroundColor(Theme.red)
                Text(sub)
                    .font(Fonts.sans(14))
                    .foregroundColor(Theme.ink(scheme))
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}
