import SwiftUI

struct NoteEditorSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let paragraphID: String
    let label: String
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Note · \(label)")
                .font(Fonts.sans(12, weight: 600))
                .kerning(1.3)
                .textCase(.uppercase)
                .foregroundColor(Theme.red)
                .padding(.top, 24)

            TextEditor(text: $draft)
                .font(Fonts.serif(16))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 140)
                .background(Theme.paperDeep(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 22) {
                Button("Save") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.setNote(trimmed.isEmpty ? nil : trimmed, for: paragraphID)
                    dismiss()
                }
                .font(Fonts.sans(14, weight: 600))
                .foregroundColor(Theme.red)

                Button("Cancel") { dismiss() }
                    .font(Fonts.sans(14))
                    .foregroundColor(Theme.inkSoft(scheme))

                if store.notes[paragraphID] != nil {
                    Button("Delete") {
                        store.setNote(nil, for: paragraphID)
                        dismiss()
                    }
                    .font(Fonts.sans(14))
                    .foregroundColor(Theme.inkSoft(scheme))
                }
                Spacer()
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.paper(scheme))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { draft = store.notes[paragraphID] ?? "" }
    }
}
