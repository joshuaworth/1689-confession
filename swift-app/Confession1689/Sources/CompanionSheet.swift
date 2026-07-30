import SwiftUI

#if canImport(FoundationModels)

/// The companion's answer, typeset like everything else: paper, EB Garamond,
/// and the red rule drawing downward as the text streams — the site's scholium
/// reveal used as the progress indicator, so there is no spinner anywhere.
@available(iOS 26.0, *)
struct CompanionSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var companion = StudyCompanion()

    let paragraphID: String
    let label: String
    let paragraph: String
    let proofRefs: [String]
    var initialAction: CompanionAction = .plainEnglish
    let jumpToChapter: (Int) -> Void

    @State private var question = ""
    @State private var action: CompanionAction = .plainEnglish
    @FocusState private var asking: Bool

    private let library = Library.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                actionRow.padding(.bottom, 20)
                if case .question = action { questionField.padding(.bottom, 18) }
                answer
                disclosure
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.paper(scheme).ignoresSafeArea())
        .onAppear {
            action = initialAction
            start(initialAction)
        }
        .onDisappear { companion.stop() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Study Companion")
                    .font(Fonts.sans(11, weight: 600))
                    .kerning(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.red)
                Text(label)
                    .font(Fonts.serif(28, weight: 500))
                    .foregroundColor(Theme.red)
            }
            Spacer()
            Button {
                companion.stop()
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
        .padding(.bottom, 20)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            chip("Plain English", isOn: action == .plainEnglish) { start(.plainEnglish) }
            chip("Ask", isOn: isAsking) {
                action = .question(question)
                companion.stop()
                asking = true
            }
            chip("Related", isOn: action == .relatedChapters) { start(.relatedChapters) }
            Spacer()
            if companion.isRunning {
                Button("Stop") { companion.stop() }
                    .font(Fonts.sans(12.5, weight: 600))
                    .foregroundColor(Theme.inkSoft(scheme))
                    .buttonStyle(.plain)
            }
        }
    }

    private var isAsking: Bool {
        if case .question = action { return true }
        return false
    }

    private func chip(_ title: String, isOn: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title)
                .font(Fonts.sans(13, weight: isOn ? 600 : 500))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(isOn ? Theme.red : .clear)
                .foregroundColor(isOn ? Theme.paper(scheme) : Theme.inkSoft(scheme))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? Theme.red : Theme.rule(scheme), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var questionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Ask about this paragraph", text: $question)
                    .font(Fonts.serif(17))
                    .focused($asking)
                    .submitLabel(.go)
                    .onSubmit { if !question.isEmpty { start(.question(question)) } }
                if !question.isEmpty {
                    Button("Ask") { start(.question(question)) }
                        .font(Fonts.sans(13, weight: 600))
                        .foregroundColor(Theme.red)
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            .background(Theme.paperDeep(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            if question.isEmpty {
                HStack(spacing: 8) {
                    ForEach(["What does this mean?", "Which scriptures support this?"], id: \.self) { suggestion in
                        Button {
                            question = suggestion
                            start(.question(suggestion))
                        } label: {
                            Text(suggestion)
                                .font(Fonts.sans(12))
                                .foregroundColor(Theme.inkSoft(scheme))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .stroke(Theme.rule(scheme), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var answer: some View {
        if let failure = companion.failure {
            Text(failure)
                .font(Fonts.sans(14))
                .foregroundColor(Theme.inkSoft(scheme))
                .padding(.bottom, 20)
        } else if action == .relatedChapters {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(companion.related, id: \.number) { item in
                    relatedRow(item)
                }
            }
            .padding(.leading, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topLeading) { rule(active: !companion.related.isEmpty) }
            .padding(.bottom, 22)
        } else {
            Text(companion.text)
                .font(Fonts.serif(store.bodySize))
                .lineSpacing(store.bodySize * 0.55)
                .foregroundColor(Theme.ink(scheme))
                .textSelection(.enabled)
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topLeading) { rule(active: !companion.text.isEmpty) }
                .padding(.bottom, 22)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: companion.text)
        }
    }

    /// The scholium rule, drawn in as content arrives.
    private func rule(active: Bool) -> some View {
        Rectangle()
            .fill(Theme.red)
            .frame(width: 2)
            .scaleEffect(y: active ? 1 : 0, anchor: .top)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: active)
    }

    private func relatedRow(_ item: RelatedChapterRef) -> some View {
        Button {
            companion.stop()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { jumpToChapter(item.number) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Chapter \(Roman.numeral(item.number)) — \(chapterTitle(item.number))")
                    .font(Fonts.sans(13, weight: 600))
                    .foregroundColor(Theme.red)
                Text(item.reason)
                    .font(Fonts.serif(16))
                    .lineSpacing(4)
                    .foregroundColor(Theme.ink(scheme))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func chapterTitle(_ number: Int) -> String {
        library.confession.chapters.first { $0.number == number }?.title ?? ""
    }

    private var disclosure: some View {
        Text("Generated on your device from this paragraph and the scripture it cites. It is not part of the confession, and it is not a substitute for reading the text itself.")
            .font(Fonts.sans(11.5))
            .lineSpacing(3)
            .foregroundColor(Theme.inkSoft(scheme).opacity(0.85))
            .padding(.top, 4)
    }

    // MARK: Running

    private func start(_ next: CompanionAction) {
        action = next
        asking = false
        let proofs: [(String, String)] = proofRefs.flatMap { reference -> [(String, String)] in
            (library.verses(for: reference) ?? []).compactMap { verse in
                guard let text = verse.b ?? verse.k ?? verse.w else { return nil }
                return (verse.r, text)
            }
        }
        companion.run(next, paragraphLabel: label, paragraph: paragraph, proofs: proofs)
    }
}

#endif
