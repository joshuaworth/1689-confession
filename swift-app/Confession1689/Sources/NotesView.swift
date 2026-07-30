import SwiftUI

/// Every note in one place, in document order, each a way back into the text.
struct NotesView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let scrollTo: (String) -> Void

    private let library = Library.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Study")
                            .font(Fonts.sans(11, weight: 600))
                            .kerning(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.red)
                        Text("Notes")
                            .font(Fonts.serif(32, weight: 500))
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
                .padding(.bottom, 24)

                if ordered.isEmpty {
                    Text("No notes yet. Press and hold any paragraph to write one.")
                        .font(Fonts.sans(14))
                        .foregroundColor(Theme.inkSoft(scheme))
                        .padding(.top, 20)
                } else {
                    ForEach(ordered, id: \.self) { id in
                        noteRow(id)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
        .background(Theme.paper(scheme).ignoresSafeArea())
    }

    private var ordered: [String] {
        let order = library.paragraphOrder
        return store.notes.keys.sorted {
            (order.firstIndex(of: $0) ?? .max) < (order.firstIndex(of: $1) ?? .max)
        }
    }

    private func noteRow(_ id: String) -> some View {
        Button {
            dismiss()
            scrollTo(id)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(library.label(for: id))
                    .font(Fonts.sans(12, weight: 600))
                    .foregroundColor(Theme.red)

                if let found = library.paragraph(for: id) {
                    Text(String(found.paragraph.text.prefix(120)) + "…")
                        .font(Fonts.serif(15))
                        .lineSpacing(3)
                        .foregroundColor(Theme.inkSoft(scheme))
                        .lineLimit(2)
                }

                Text(store.notes[id] ?? "")
                    .font(Fonts.serif(16))
                    .lineSpacing(5)
                    .foregroundColor(Theme.ink(scheme))
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.red).frame(width: 2)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
