import SwiftUI
import UIKit

// MARK: - Paragraph

struct ParagraphView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let paragraphID: String
    let label: String
    let number: Int
    let text: String
    let proofRefs: [String]
    @Binding var flashedID: String?

    @State private var expandedRef: String?
    @State private var editingNote = false
    @State private var shareCard: ShareCardItem?
    @State private var chapterReference: ProofReference?

    private let library = Library.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            body_text

            if let ref = expandedRef, let verses = library.verses(for: ref) {
                VerseScholium(reference: ref, verses: verses,
                              readChapter: { chapterReference = ProofReference(ref) },
                              close: { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { expandedRef = nil } })
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let note = store.notes[paragraphID], !note.isEmpty {
                NoteScholium(note: note) { editingNote = true }
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, 18)
        .id(paragraphID)
        .background(
            (flashedID == paragraphID ? Theme.red.opacity(0.10) : Color.clear)
                .animation(.easeOut(duration: 1.2), value: flashedID)
        )
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "proof" else { return .systemAction }
            let ref = url.absoluteString
                .replacingOccurrences(of: "proof://", with: "")
                .removingPercentEncoding ?? ""
            Haptics.proof()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.26)) {
                expandedRef = (expandedRef == ref) ? nil : ref
            }
            return .handled
        })
        .sheet(isPresented: $editingNote) {
            NoteEditorSheet(paragraphID: paragraphID, label: label)
                .environmentObject(store)
        }
        .sheet(item: $shareCard) { item in
            ShareCardSheet(item: item)
        }
        .fullScreenCover(item: $chapterReference) { reference in
            BibleChapterSheet(reference: reference,
                              citedIn: paragraphID,
                              jumpBack: { store.destination = $0 })
                .environmentObject(store)
        }
    }

    private var body_text: some View {
        Text(attributed)
            .lineSpacing(CGFloat(store.bodySize) * 0.55)
            .tint(Theme.red)
            .accessibilityAction(named: store.isBookmarked(paragraphID) ? "Remove Bookmark" : "Bookmark") {
                store.toggleBookmark(paragraphID)
            }
            .accessibilityAction(named: store.notes[paragraphID] == nil ? "Add Note" : "Edit Note") {
                editingNote = true
            }
            .onAppear {
                store.recordPosition(paragraphID)
                #if DEBUG
                if let seed = UserDefaults.standard.string(forKey: "seedProof"),
                   seed.hasPrefix(paragraphID + "|") {
                    expandedRef = String(seed.dropFirst(paragraphID.count + 1))
                }
                if let seed = UserDefaults.standard.string(forKey: "seedChapter"),
                   seed.hasPrefix(paragraphID + "|") {
                    chapterReference = ProofReference(String(seed.dropFirst(paragraphID.count + 1)))
                }
                #endif
            }
            .contextMenu {
                Button {
                    Haptics.bookmark()
                    store.toggleBookmark(paragraphID)
                } label: {
                    Label(store.isBookmarked(paragraphID) ? "Remove Bookmark" : "Bookmark",
                          systemImage: store.isBookmarked(paragraphID) ? "bookmark.slash" : "bookmark")
                }
                Button {
                    editingNote = true
                } label: {
                    Label(store.notes[paragraphID] == nil ? "Add Note" : "Edit Note",
                          systemImage: "square.and.pencil")
                }
                Button {
                    UIPasteboard.general.string = "https://1689.intentmesh.dev/#\(paragraphID)"
                } label: {
                    Label("Copy Link", systemImage: "link")
                }
                ShareLink(item: "\(label) — \(text)\n\nhttps://1689.intentmesh.dev/#\(paragraphID)") {
                    Label("Share Text", systemImage: "square.and.arrow.up")
                }
                Button {
                    shareCard = ShareCardItem(label: label, text: text)
                } label: {
                    Label("Share as Card", systemImage: "photo")
                }
            }
    }

    /// Paragraph number (tappable menu rendered separately is not possible inline,
    /// so the number is part of the text and the actions live in a context menu
    /// plus a small trailing menu button row on the number via overlay).
    private var attributed: AttributedString {
        var output = AttributedString()

        var pnum = AttributedString("\(number)  ")
        pnum.font = Fonts.sans(store.bodySize * 0.62, weight: 600)
        pnum.foregroundColor = Theme.red
        if store.isBookmarked(paragraphID) {
            pnum.underlineStyle = .single
        }
        output += pnum

        var body = AttributedString(text)
        body.font = Fonts.serif(store.bodySize)
        body.foregroundColor = Theme.ink(scheme)
        output += body

        if store.showProofs && !proofRefs.isEmpty {
            var open = AttributedString("  ( ")
            open.font = Fonts.sans(store.bodySize * 0.72)
            open.foregroundColor = Theme.inkSoft(scheme)
            output += open

            for (index, ref) in proofRefs.enumerated() {
                var link = AttributedString(ref)
                link.font = Fonts.sans(store.bodySize * 0.72, weight: expandedRef == ref ? 700 : 500)
                link.foregroundColor = Theme.red
                if let encoded = ref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "proof://\(encoded)") {
                    link.link = url
                }
                output += link
                if index < proofRefs.count - 1 {
                    var separator = AttributedString("; ")
                    separator.font = Fonts.sans(store.bodySize * 0.72)
                    separator.foregroundColor = Theme.inkSoft(scheme)
                    output += separator
                }
            }
            var close = AttributedString(" )")
            close.font = Fonts.sans(store.bodySize * 0.72)
            close.foregroundColor = Theme.inkSoft(scheme)
            output += close
        }
        return output
    }
}

// MARK: - Verse scholium (the in-flow proof text)

struct VerseScholium: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    let reference: String
    let verses: [Verse]
    var readChapter: (() -> Void)?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(reference) · \(store.translation.label)")
                    .font(Fonts.sans(12, weight: 600))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.red)
                Spacer()
                Button("Close ✕", action: close)
                    .font(Fonts.sans(12, weight: 500))
                    .foregroundColor(Theme.inkSoft(scheme))
                    .buttonStyle(.plain)
            }

            ForEach(verses, id: \.r) { verse in
                verseRow(verse)
                    .textSelection(.enabled)
            }

            if let readChapter, let parsed = ProofReference(reference) {
                Button(action: readChapter) {
                    Text("Read \(parsed.title) →")
                        .font(Fonts.sans(12, weight: 600))
                        .foregroundColor(Theme.red)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Text("Berean Standard Bible and World English Bible are public domain; KJV is Crown copyright expired.")
                .font(Fonts.sans(11))
                .foregroundColor(Theme.inkSoft(scheme).opacity(0.75))
                .padding(.top, 2)
        }
        .padding(.leading, 18)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.red).frame(width: 2)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func verseRow(_ verse: Verse) -> some View {
        if store.translation == .parallel {
            VStack(alignment: .leading, spacing: 4) {
                ForEach([Translation.bsb, .kjv, .web], id: \.self) { translation in
                    if let text = verse.text(for: translation) {
                        parallelLine(reference: verse.r, badge: translation.label, text: text)
                    }
                }
            }
            .padding(.bottom, 6)
        } else if let text = verse.text(for: store.translation) ?? verse.b ?? verse.k ?? verse.w {
            (refSpan(verse.r) + textSpan(text))
                .lineSpacing(5)
        }
    }

    private func parallelLine(reference: String, badge: String, text: String) -> some View {
        (badgeSpan(badge) + refSpan(reference) + textSpan(text)).lineSpacing(4)
    }

    private func badgeSpan(_ label: String) -> Text {
        Text("\(label)  ").font(Fonts.sans(10.5, weight: 700)).foregroundColor(Theme.red)
    }
    private func refSpan(_ reference: String) -> Text {
        Text("\(reference)  ").font(Fonts.sans(11.5, weight: 600)).foregroundColor(Theme.inkSoft(scheme))
    }
    private func textSpan(_ text: String) -> Text {
        Text(text).font(Fonts.serif(max(14, store.bodySize * 0.9))).foregroundColor(Theme.ink(scheme))
    }
}

// MARK: - Note scholium

struct NoteScholium: View {
    @Environment(\.colorScheme) private var scheme
    let note: String
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Note")
                    .font(Fonts.sans(11, weight: 600))
                    .kerning(1.3)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.red)
                Text(note)
                    .font(Fonts.serif(15))
                    .lineSpacing(5)
                    .foregroundColor(Theme.ink(scheme))
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.red).frame(width: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
