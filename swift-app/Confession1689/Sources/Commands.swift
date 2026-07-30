import SwiftUI

/// Keyboard shortcuts and, on Mac, the menu bar. Everything here is a shortcut
/// to something the reader can already reach by touch — nothing is exclusive
/// to the keyboard.
struct ReaderCommands: Commands {
    @ObservedObject var store: StudyStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Read") {
            Button("Search…") { store.destination = "search" }
                .keyboardShortcut("f", modifiers: .command)
            Button("Contents") { store.destination = "contents" }
                .keyboardShortcut("l", modifiers: .command)
            Divider()
            Button("Today's Reading") { store.destination = "today" }
                .keyboardShortcut("t", modifiers: .command)
            Button("Bookmarks") { store.destination = "bookmarks" }
                .keyboardShortcut("b", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Larger Text") { store.fontStep = min(4, store.fontStep + 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { store.fontStep = max(0, store.fontStep - 1) }
                .keyboardShortcut("-", modifiers: .command)
            Divider()
            Button(store.darkOverride == true ? "Daylight" : "Candlelight") {
                store.darkOverride = !(store.darkOverride ?? false)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            Button(store.showProofs ? "Hide Scripture Proofs" : "Show Scripture Proofs") {
                store.showProofs.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
