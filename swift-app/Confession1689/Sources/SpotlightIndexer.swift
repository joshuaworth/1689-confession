import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Makes every chapter and paragraph findable from the iOS home screen search.
enum SpotlightIndexer {
    private static let indexedKey = "spotlightIndexed.v1"

    static func indexIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: indexedKey) else { return }
        let library = Library.shared

        var items: [CSSearchableItem] = []
        for chapter in library.confession.chapters {
            let chapterAttributes = CSSearchableItemAttributeSet(contentType: .text)
            chapterAttributes.title = "Chapter \(chapter.roman) — \(chapter.title)"
            chapterAttributes.contentDescription = chapter.paragraphs.first.map { String($0.text.prefix(160)) }
            items.append(CSSearchableItem(uniqueIdentifier: "ch\(chapter.number)",
                                          domainIdentifier: "confession",
                                          attributeSet: chapterAttributes))

            for paragraph in chapter.paragraphs {
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = "1689 · Chapter \(chapter.roman) ¶ \(paragraph.number)"
                attributes.contentDescription = String(paragraph.text.prefix(220))
                items.append(CSSearchableItem(uniqueIdentifier: "c\(chapter.number)p\(paragraph.number)",
                                              domainIdentifier: "confession",
                                              attributeSet: attributes))
            }
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: indexedKey)
            }
        }
    }
}
