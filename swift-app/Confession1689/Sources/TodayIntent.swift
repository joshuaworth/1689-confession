import AppIntents
import Foundation

/// "Hey Siri, today's 1689 reading" — speaks the day's paragraph.
struct TodayReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's 1689 Reading"
    static var description = IntentDescription("Reads today's paragraph from the Baptist Confession of Faith.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let library = Library.shared
        let id = library.todayParagraphID()
        guard let found = library.paragraph(for: id) else {
            return .result(dialog: "The confession could not be loaded.")
        }
        await MainActor.run { StudyStore.shared.recordTodayRead() }
        let label = "Chapter \(found.chapter.roman), paragraph \(found.paragraph.number), \(found.chapter.title)."
        return .result(dialog: IntentDialog(stringLiteral: label + " " + found.paragraph.text))
    }
}

/// "Read 1689 chapter eleven" — speaks a chapter's opening paragraph.
struct ReadChapterIntent: AppIntent {
    static var title: LocalizedStringResource = "Read a 1689 Chapter"
    static var description = IntentDescription("Reads the opening of a chapter from the Baptist Confession of Faith.")

    @Parameter(title: "Chapter", inclusiveRange: (1, 32))
    var chapter: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let found = Library.shared.confession.chapters.first(where: { $0.number == chapter }),
              let first = found.paragraphs.first else {
            return .result(dialog: "There are thirty-two chapters. Ask for a chapter between one and thirty-two.")
        }
        let intro = "Chapter \(found.roman), \(found.title), paragraph one."
        return .result(dialog: IntentDialog(stringLiteral: intro + " " + first.text))
    }
}

/// "Open 1689 to chapter eleven" — opens the app at that chapter.
struct OpenChapterIntent: AppIntent {
    static var title: LocalizedStringResource = "Open a 1689 Chapter"
    static var description = IntentDescription("Opens the Baptist Confession of Faith at a chapter.")
    static var openAppWhenRun = true

    @Parameter(title: "Chapter", inclusiveRange: (1, 32))
    var chapter: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        StudyStore.shared.destination = "ch\(chapter)"
        return .result()
    }
}

/// "Search 1689 for effectual calling" — opens the app with the search ready.
struct SearchConfessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Search the 1689"
    static var description = IntentDescription("Searches the Baptist Confession of Faith and its scripture proofs.")
    static var openAppWhenRun = true

    @Parameter(title: "Phrase")
    var phrase: String

    @MainActor
    func perform() async throws -> some IntentResult {
        StudyStore.shared.pendingSearchQuery = phrase
        StudyStore.shared.destination = "search"
        return .result()
    }
}

struct ConfessionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TodayReadingIntent(),
                    phrases: ["Today's ${applicationName} reading",
                              "Read today's paragraph from ${applicationName}"],
                    shortTitle: "Today's Reading",
                    systemImageName: "book")
        AppShortcut(intent: ReadChapterIntent(),
                    phrases: ["Read a chapter from ${applicationName}",
                              "Read ${applicationName} chapter"],
                    shortTitle: "Read a Chapter",
                    systemImageName: "text.book.closed")
        AppShortcut(intent: SearchConfessionIntent(),
                    phrases: ["Search ${applicationName}"],
                    shortTitle: "Search",
                    systemImageName: "magnifyingglass")
    }
}
