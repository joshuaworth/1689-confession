import SwiftUI
import TipKit

/// Two gestures carry most of the app and neither is visible: pressing a
/// paragraph, and tapping a scripture reference. TipKit teaches each once and
/// then never again — including across reinstalls of the same device.
struct ParagraphMenuTip: Tip {
    var title: Text { Text("Press and hold any paragraph") }
    var message: Text? { Text("Bookmark it, write a note, share it, or ask about it.") }
    var image: Image? { Image(systemName: "hand.tap") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(2)] }
}

struct ProofTapTip: Tip {
    var title: Text { Text("Tap any scripture reference") }
    var message: Text? { Text("The verses open here, in three translations, without leaving the page.") }
    var image: Image? { Image(systemName: "book") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(2)] }
}

enum ReaderTips {
    static func configure() {
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault),
        ])
    }
}
