import SwiftUI

@main
struct ConfessionApp: App {
    @StateObject private var store = StudyStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
                .task {
                    SpotlightIndexer.indexIfNeeded()
                    #if DEBUG
                    Library.shared.assertProofIntegrity()
                    #endif
                }
        }
    }
}

#if DEBUG
extension Library {
    /// Every proof reference on every paragraph must resolve to bundled verses.
    func assertProofIntegrity() {
        var missing: [String] = []
        for chapter in confession.chapters {
            for paragraph in chapter.paragraphs {
                for ref in paragraph.proofRefs where verses(for: ref) == nil {
                    missing.append(ref)
                }
            }
        }
        assert(missing.isEmpty, "Unresolvable proof refs: \(missing)")
    }
}
#endif
