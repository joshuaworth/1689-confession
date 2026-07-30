import SwiftUI

/// Flat row model: every paragraph is a direct child of the lazy stack so
/// `scrollPosition(id:)` can land on any of them reliably.
enum ReaderRow: Identifiable {
    case hero
    case sectionHeader(kicker: String, title: String, anchor: String)
    /// Apparatus headers rest closed; `count` is shown as a meta line.
    case apparatusHeader(kicker: String, title: String, anchor: String, count: Int)
    case paragraph(id: String, label: String, number: Int, text: String, proofRefs: [String])
    case signatories
    case colophon

    var id: String {
        switch self {
        case .hero: return "top"
        case .sectionHeader(_, _, let anchor): return anchor
        case .apparatusHeader(_, _, let anchor, _): return anchor
        case .paragraph(let id, _, _, _, _): return id
        case .signatories: return "signatories"
        case .colophon: return "colophon"
        }
    }

    /// The apparatus section a row belongs to, for collapse filtering.
    var apparatusOwner: String? {
        if case .paragraph(let id, _, _, _, _) = self {
            if id.hasPrefix("preface-") { return "preface" }
            if id.hasPrefix("appendix-") { return "appendix" }
        }
        return nil
    }
}

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @State private var showContents = false
    @State private var showSearch = false
    @State private var flashedID: String?
    @State private var scrollID: String?
    @State private var openApparatus: Set<String> = []
    /// Offered at the top on a cold launch instead of jumping there unasked.
    @State private var resumeTarget: String?
    @State private var showNotes = false
    @State private var showFirstRun = false
    /// Where the reader was before a jump, so the thread is never lost.
    @State private var returnTarget: String?
    @State private var lastChapterCrossed: String?

    private let library = Library.shared

    private static let rows: [ReaderRow] = {
        let library = Library.shared
        // Site document order: preface, the 32 chapters, appendix, signatories.
        var rows: [ReaderRow] = [.hero]
        func apparatus(_ prefix: String, _ kicker: String, _ section: Apparatus.Section) {
            rows.append(.apparatusHeader(kicker: kicker, title: section.title,
                                         anchor: prefix, count: section.paragraphs.count))
            for (index, text) in section.paragraphs.enumerated() {
                rows.append(.paragraph(id: "\(prefix)-p\(index + 1)",
                                       label: "\(section.title) · ¶ \(index + 1)",
                                       number: index + 1, text: text, proofRefs: []))
            }
        }
        apparatus("preface", "Preface · 1677", library.apparatus.preface)
        for chapter in library.confession.chapters {
            rows.append(.sectionHeader(kicker: "Chapter \(chapter.roman)",
                                       title: chapter.title,
                                       anchor: "ch\(chapter.number)"))
            for paragraph in chapter.paragraphs {
                rows.append(.paragraph(id: "c\(chapter.number)p\(paragraph.number)",
                                       label: "Chapter \(chapter.roman) · ¶ \(paragraph.number)",
                                       number: paragraph.number,
                                       text: paragraph.text,
                                       proofRefs: paragraph.proofRefs))
            }
        }
        apparatus("appendix", "Appendix · 1677", library.apparatus.appendix)
        rows.append(.signatories)
        rows.append(.colophon)
        return rows
    }()

    var body: some View {
        if horizontalSize == .regular {
            // iPad and Mac: the contents live beside the text rather than over it.
            NavigationSplitView {
                SidebarView(scrollTo: scrollTo, openNotes: { showNotes = true })
                    .environmentObject(store)
            } detail: {
                reader
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            reader
        }
    }

    private var reader: some View {
        ZStack(alignment: .top) {
            Theme.paper(scheme).ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleRows) { row in
                        rowView(row)
                            .padding(.horizontal, horizontalSize == .regular ? 32 : 20)
                            // Hold the line length near 70 characters. A wide
                            // screen buys margin, never a longer measure.
                            .frame(maxWidth: measure, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, 52)
            }
            .scrollPosition(id: $scrollID, anchor: .top)
            .scrollIndicators(.hidden)

            TopBar(showSearch: $showSearch, showContents: $showContents,
                   context: currentContext, showsContentsButton: horizontalSize != .regular,
                   scrollTo: scrollTo)

            if let target = returnTarget {
                returnPill(target)
            }
        }
        .fullScreenCover(isPresented: $showFirstRun) {
            FirstRunView { showFirstRun = false }
        }
        .onChange(of: store.destination) { _, destination in
            guard let destination else { return }
            store.destination = nil
            switch destination {
            case "search": showSearch = true
            case "bookmarks", "contents": showContents = true
            case "today": scrollTo(library.todayParagraphID())
            default: scrollTo(destination)
            }
        }
        .onAppear {
            #if DEBUG
            // Test seeds that target a paragraph need that paragraph on screen.
            for key in ["seedCompanion", "seedProof", "seedChapter"] {
                if let seed = UserDefaults.standard.string(forKey: key),
                   let id = seed.split(separator: "|").first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollID = String(id) }
                    break
                }
            }
            switch UserDefaults.standard.string(forKey: "seedOverlay") {
            case "contents": DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showContents = true }
            case "search": DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showSearch = true }
            default: break
            }
            #endif
            // A cold launch opens at the top; the last place is offered, never forced.
            store.restoring = false
            if !store.hasLaunched {
                store.hasLaunched = true
                showFirstRun = true
            }
            if let position = store.position, position != "top",
               library.paragraph(for: position) != nil || position.hasPrefix("ch") {
                resumeTarget = position
            }
        }
        .fullScreenCover(isPresented: $showContents) {
            ContentsSheet(scrollTo: scrollTo, openNotes: { showNotes = true })
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(scrollTo: scrollTo)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showNotes) {
            NotesView(scrollTo: scrollTo)
                .environmentObject(store)
        }
        // Handoff: the reader's place travels to their other devices.
        .userActivity("dev.intentmesh.confession.reading", isActive: scrollID != nil) { activity in
            guard let id = scrollID else { return }
            activity.title = library.label(for: id)
            activity.webpageURL = URL(string: "https://1689.intentmesh.dev/p/\(id)")
            activity.isEligibleForHandoff = true
            activity.userInfo = ["paragraph": id]
        }
        .onContinueUserActivity("dev.intentmesh.confession.reading") { activity in
            if let id = activity.userInfo?["paragraph"] as? String { store.destination = id }
        }
        .onChange(of: scrollID) { _, id in
            guard let id, let chapter = chapterAnchor(for: id) else { return }
            if lastChapterCrossed != nil && lastChapterCrossed != chapter {
                Haptics.chapterBoundary()
            }
            lastChapterCrossed = chapter
        }
    }

    /// Line length scales with the reader's chosen text size, not the screen.
    private var measure: CGFloat {
        horizontalSize == .regular ? store.bodySize * 34 : 700
    }

    /// The chapter or apparatus section a row id belongs to.
    private func chapterAnchor(for id: String) -> String? {
        if id.hasPrefix("preface") { return "preface" }
        if id.hasPrefix("appendix") { return "appendix" }
        if let match = id.wholeMatch(of: #/c(\d+)p\d+/#) { return "ch\(match.1)" }
        if id.hasPrefix("ch") { return id }
        return nil
    }

    /// "XIV · Of Saving Faith" for the top bar, derived from the visible row.
    private var currentContext: String? {
        guard let id = scrollID, let anchor = chapterAnchor(for: id),
              anchor.hasPrefix("ch"), let number = Int(anchor.dropFirst(2)),
              let chapter = library.confession.chapters.first(where: { $0.number == number })
        else { return nil }
        return "\(chapter.roman) · \(chapter.title)"
    }

    private func returnPill(_ target: String) -> some View {
        VStack {
            Spacer()
            Button {
                returnTarget = nil
                scrollID = target
                Haptics.arrive()
            } label: {
                Text("↩  Return to \(library.label(for: target))")
                    .font(Fonts.sans(13, weight: 600))
                    .foregroundColor(Theme.paper(scheme))
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Theme.red)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    /// Apparatus paragraphs are hidden until their header is opened.
    private var visibleRows: [ReaderRow] {
        Self.rows.filter { row in
            guard let owner = row.apparatusOwner else { return true }
            return openApparatus.contains(owner)
        }
    }

    @ViewBuilder
    private func rowView(_ row: ReaderRow) -> some View {
        switch row {
        case .hero:
            HeroView(scrollTo: scrollTo, resumeTarget: $resumeTarget)
        case .sectionHeader(let kicker, let title, _):
            SectionHeaderView(kicker: kicker, title: title)
        case .apparatusHeader(let kicker, let title, let anchor, let count):
            ApparatusHeaderView(kicker: kicker, title: title, count: count,
                                isOpen: openApparatus.contains(anchor)) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.26)) {
                    if openApparatus.contains(anchor) { openApparatus.remove(anchor) }
                    else { openApparatus.insert(anchor) }
                }
            }
        case .paragraph(let id, let label, let number, let text, let proofRefs):
            ParagraphView(paragraphID: id, label: label, number: number,
                          text: text, proofRefs: proofRefs, flashedID: $flashedID)
        case .signatories:
            SignatoriesView(signatories: library.apparatus.signatories)
        case .colophon:
            ColophonView()
        }
    }

    private func scrollTo(_ id: String) {
        showContents = false
        showSearch = false
        if id == library.todayParagraphID() {
            store.recordTodayRead()
            ReviewPrompt.considerAsking(streak: store.streak,
                                        bookmarks: store.bookmarks.count,
                                        notes: store.notes.count)
        }

        // Offer the way back when a jump leaves a genuinely different place.
        let origin = scrollID
        if let origin, origin != id, origin != "top",
           chapterAnchor(for: origin) != chapterAnchor(for: id) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { returnTarget = origin }
            DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if returnTarget == origin { returnTarget = nil }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { scrollID = id }
            flash(id)
        }
    }

    private func flash(_ id: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            flashedID = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if flashedID == id { flashedID = nil }
            }
        }
    }
}

// MARK: - Apparatus header (rests closed, unfolds on tap)

struct ApparatusHeaderView: View {
    @Environment(\.colorScheme) private var scheme
    let kicker: String
    let title: String
    let count: Int
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
                    .padding(.top, 44).padding(.bottom, 36)

                Text(kicker)
                    .font(Fonts.sans(12, weight: 600))
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.red)
                    .padding(.bottom, 8)

                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(title)
                        .font(Fonts.serif(32, weight: 500))
                        .foregroundColor(Theme.red)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text(isOpen ? "▲" : "▼")
                        .font(Fonts.sans(12))
                        .foregroundColor(Theme.inkSoft(scheme))
                }

                Text(isOpen ? "Tap to close" : "\(count) paragraphs · tap to read")
                    .font(Fonts.sans(12.5))
                    .foregroundColor(Theme.inkSoft(scheme))
                    .padding(.top, 8)
                    .padding(.bottom, isOpen ? 24 : 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) paragraphs")
        .accessibilityHint(isOpen ? "Closes this section" : "Opens this section")
    }
}

// MARK: - Section header (chapter or apparatus)

struct SectionHeaderView: View {
    @Environment(\.colorScheme) private var scheme
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
                .padding(.top, 44).padding(.bottom, 36)

            Text(kicker)
                .font(Fonts.sans(12, weight: 600))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.red)
                .padding(.bottom, 8)

            Text(title)
                .font(Fonts.serif(32, weight: 500))
                .foregroundColor(Theme.red)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    @Binding var showSearch: Bool
    @Binding var showContents: Bool
    let context: String?
    var showsContentsButton: Bool = true
    let scrollTo: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button { scrollTo("top") } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    (Text("1689").foregroundColor(Theme.ink(scheme))
                     + Text(".").foregroundColor(Theme.red))
                        .font(Fonts.sans(21, weight: 700))
                    if let context {
                        Text(context)
                            .font(Fonts.sans(12, weight: 500))
                            .foregroundColor(Theme.inkSoft(scheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: context)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 6)

            barButton("magnifyingglass", label: "Search") { showSearch = true }
            barButton(scheme == .dark ? "sun.max" : "moon",
                      label: scheme == .dark ? "Switch to light mode" : "Switch to candlelight") {
                store.darkOverride = !(scheme == .dark)
            }
            if showsContentsButton {
                barButton("line.3.horizontal", label: "Contents and settings") { showContents = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Theme.paper(scheme)
                .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
        }
    }

    private func barButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Theme.ink(scheme))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Hero

struct HeroView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme
    let scrollTo: (String) -> Void
    @Binding var resumeTarget: String?
    private let library = Library.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("The Second London Baptist Confession · 1689")
                .font(Fonts.sans(12, weight: 600))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.red)
                .padding(.top, 44)
                .padding(.bottom, 18)

            Text("The Baptist\nConfession\nof Faith")
                .font(Fonts.serif(58, weight: 500))
                .foregroundColor(Theme.red)
                .padding(.bottom, 22)

            Text("Thirty-two chapters. Every scripture proof one tap away, in three public-domain translations. No ads, no account, just the text.")
                .font(Fonts.sans(16.5))
                .lineSpacing(5)
                .foregroundColor(Theme.inkSoft(scheme))
                .padding(.bottom, 20)

            Text("32 chapters · 770 scripture proofs · BSB · KJV · WEB · Public domain")
                .font(Fonts.sans(12.5, weight: 500))
                .foregroundColor(Theme.inkSoft(scheme))
                .padding(.bottom, 22)

            todayRow
                .padding(.bottom, resumeTarget == nil ? 40 : 18)

            if let target = resumeTarget {
                Button {
                    resumeTarget = nil
                    scrollTo(target)
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue reading")
                            .font(Fonts.sans(13, weight: 600))
                        Text(library.label(for: target))
                            .font(Fonts.sans(13))
                        Text("→")
                            .font(Fonts.sans(13, weight: 600))
                    }
                    .foregroundColor(Theme.red)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.red, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }

    private var todayRow: some View {
        let id = library.todayParagraphID()
        let label = library.label(for: id)
        let title = library.paragraph(for: id)?.chapter.title ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Today's Reading")
                    .font(Fonts.sans(11, weight: 600))
                    .kerning(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.inkSoft(scheme))
                if store.streak >= 2 {
                    Text("\(store.streak)-day streak")
                        .font(Fonts.sans(11, weight: 500))
                        .foregroundColor(Theme.inkSoft(scheme))
                }
            }
            Button { scrollTo(id) } label: {
                Text("\(label) · \(title)")
                    .font(Fonts.sans(13.5, weight: 500))
                    .foregroundColor(Theme.red)
                    .underline()
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Colophon

struct ColophonView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
                .padding(.bottom, 30)
            Text("Soli Deo Gloria")
                .font(Fonts.serif(19, italic: true))
                .foregroundColor(Theme.red)
            Text("The Second London Baptist Confession of Faith (1677/1689). The text is in the public domain. Tap any scripture proof to read it in the Berean Standard Bible, the King James Version, or the World English Bible, or all three in parallel.")
                .font(Fonts.sans(13))
                .lineSpacing(5)
                .foregroundColor(Theme.inkSoft(scheme))
        }
        .padding(.top, 40)
        .padding(.bottom, 90)
    }
}
