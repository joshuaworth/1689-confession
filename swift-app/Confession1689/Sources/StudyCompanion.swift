import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The on-device study companion.
///
/// It is deliberately not a chat assistant. Every answer is bound to one
/// paragraph of the confession and the scripture it cites; the model is
/// instructed to work from that text alone, to decline rather than speculate,
/// and never to speak as the confession. Nothing leaves the device, and where
/// the model is unavailable the feature is absent rather than degraded.
enum CompanionAction: Equatable, Identifiable {
    case plainEnglish
    case question(String)
    case relatedChapters

    var id: String {
        switch self {
        case .plainEnglish: return "plain"
        case .question: return "question"
        case .relatedChapters: return "related"
        }
    }

    var kicker: String {
        switch self {
        case .plainEnglish: return "In plain English"
        case .question: return "Answer"
        case .relatedChapters: return "Related chapters"
        }
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
struct RelatedChapterList {
    @Guide(description: "Chapters of the confession this paragraph itself points to", .count(1...4))
    var chapters: [RelatedChapterRef]
}

@available(iOS 26.0, *)
@Generable
struct RelatedChapterRef {
    @Guide(description: "Chapter number of the confession", .minimum(1), .maximum(32))
    var number: Int
    @Guide(description: "One short sentence, drawn only from the supplied text, on how it relates")
    var reason: String
}

@available(iOS 26.0, *)
@MainActor
final class StudyCompanion: ObservableObject {
    @Published private(set) var text: String = ""
    @Published private(set) var related: [RelatedChapterRef] = []
    @Published private(set) var isRunning = false
    @Published private(set) var failure: String?

    private var session: LanguageModelSession?
    private var task: Task<Void, Never>?

    static var isSupported: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Why the companion cannot run, phrased for a reader rather than a developer.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device does not support on-device Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to use the study companion."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again shortly."
        case .unavailable:
            return "The on-device model is unavailable right now."
        }
    }

    private static let instructions = """
        You explain one paragraph of the 1689 Baptist Confession of Faith to a reader.

        Absolute rules:
        - Use ONLY the paragraph and the scripture quotations supplied to you. They are your sole source.
        - Never add doctrine, history, or argument that is not present in that supplied text.
        - Never settle disputed questions, and never take a side the supplied text does not take.
        - If the supplied text does not answer the question, say plainly that this paragraph does not address it. Do not guess.
        - Never speak as the confession or put words in its mouth. Describe what it says.
        - Write plainly and reverently, in short paragraphs. No headings, no lists, no markdown, no emoji.
        - Be brief. Three short paragraphs at the very most.
        """

    func run(_ action: CompanionAction, paragraphLabel: String, paragraph: String, proofs: [(String, String)]) {
        stop()
        text = ""
        related = []
        failure = nil
        isRunning = true

        let session = LanguageModelSession(instructions: Self.instructions)
        self.session = session

        let source = Self.source(label: paragraphLabel, paragraph: paragraph, proofs: proofs)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                switch action {
                case .relatedChapters:
                    let response = try await session.respond(
                        to: Self.relatedPrompt(source: source),
                        generating: RelatedChapterList.self)
                    await MainActor.run {
                        self.related = response.content.chapters.filter { (1...32).contains($0.number) }
                        self.isRunning = false
                    }
                case .plainEnglish, .question:
                    let prompt = action == .plainEnglish
                        ? Self.plainPrompt(source: source)
                        : Self.questionPrompt(source: source, question: action.questionText)
                    let stream = session.streamResponse(to: prompt)
                    for try await snapshot in stream {
                        await MainActor.run { self.text = snapshot.content }
                    }
                    await MainActor.run { self.isRunning = false }
                }
            } catch is CancellationError {
                await MainActor.run { self.isRunning = false }
            } catch {
                #if DEBUG
                print("COMPANION availability=\(SystemLanguageModel.default.availability) error=\(error)")
                #endif
                await MainActor.run {
                    self.failure = Self.describe(error)
                    self.isRunning = false
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    // MARK: Prompt construction

    /// The paragraph and every verse it cites — the only material the model may use.
    private static func source(label: String, paragraph: String, proofs: [(String, String)]) -> String {
        var out = "PARAGRAPH (\(label)):\n\(paragraph)\n"
        if !proofs.isEmpty {
            out += "\nSCRIPTURE THIS PARAGRAPH CITES:\n"
            // The context window is finite; the paragraph always outranks the proofs.
            var budget = 6_000
            for (reference, verse) in proofs {
                let line = "\(reference): \(verse)\n"
                if budget - line.count < 0 { break }
                budget -= line.count
                out += line
            }
        }
        return out
    }

    private static func plainPrompt(source: String) -> String {
        """
        \(source)

        Restate this paragraph in plain modern English. Keep every claim it makes and add none of your own.
        """
    }

    private static func questionPrompt(source: String, question: String) -> String {
        """
        \(source)

        A reader asks: "\(question)"

        Answer only from the paragraph and the scripture above. If they do not answer it, say so plainly.
        """
    }

    private static func relatedPrompt(source: String) -> String {
        """
        \(source)

        Which chapters of the 1689 confession does this paragraph itself point toward, by its own subject
        matter? Give only chapters clearly implicated by the supplied text. If few qualify, give few.
        """
    }

    private static func describe(_ error: Error) -> String {
        // The model reports a bare generation error when its safety classifier
        // assets are absent (notably in the Simulator, and on a device whose
        // Apple Intelligence assets are still downloading). Say so plainly
        // rather than blaming the reader's request.
        if String(describing: error).contains("SensitiveContentAnalysis") {
            return "Apple Intelligence is still preparing on this device. The companion will work once it has finished."
        }
        guard let generation = error as? LanguageModelSession.GenerationError else {
            return "The study companion could not finish. Please try again."
        }
        switch generation {
        case .exceededContextWindowSize:
            return "This paragraph and its scriptures are too long for one pass. Try asking about a shorter portion."
        case .guardrailViolation, .refusal:
            return "The companion declined to answer that."
        case .rateLimited, .concurrentRequests:
            return "The companion is busy. Try again in a moment."
        case .assetsUnavailable:
            return "The on-device model is not ready yet."
        default:
            return "The study companion could not finish. Please try again."
        }
    }
}

private extension CompanionAction {
    var questionText: String {
        if case .question(let text) = self { return text }
        return ""
    }
}

#endif
