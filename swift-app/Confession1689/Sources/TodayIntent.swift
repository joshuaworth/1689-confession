import AppIntents

/// "Hey Siri, today's 1689 reading" — returns the day's paragraph.
struct TodayReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's 1689 Reading"
    static var description = IntentDescription("Reads today's paragraph from the Baptist Confession of Faith.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let library = Library.shared
        let id = library.todayParagraphID()
        guard let found = library.paragraph(for: id) else {
            return .result(dialog: "The confession could not be loaded.")
        }
        let label = "Chapter \(found.chapter.roman), paragraph \(found.paragraph.number), \(found.chapter.title)."
        return .result(dialog: IntentDialog(stringLiteral: label + " " + found.paragraph.text))
    }
}

struct ConfessionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TodayReadingIntent(),
                    phrases: ["Today's ${applicationName} reading",
                              "Read today's paragraph from ${applicationName}"],
                    shortTitle: "Today's Reading",
                    systemImageName: "book")
    }
}
