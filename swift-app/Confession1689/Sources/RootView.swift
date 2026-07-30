import SwiftUI

/// Flat row model: every paragraph is a direct child of the lazy stack so
/// `scrollPosition(id:)` can land on any of them reliably.
enum ReaderRow: Identifiable {
    case hero
    case sectionHeader(kicker: String, title: String, anchor: String)
    case paragraph(id: String, label: String, number: Int, text: String, proofRefs: [String])
    case signatories
    case colophon

    var id: String {
        switch self {
        case .hero: return "top"
        case .sectionHeader(_, _, let anchor): return anchor
        case .paragraph(let id, _, _, _, _): return id
        case .signatories: return "signatories"
        case .colophon: return "colophon"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var scheme

    @State private var showContents = false
    @State private var showSearch = false
    @State private var flashedID: String?
    @State private var scrollID: String?

    private let library = Library.shared

    private static let rows: [ReaderRow] = {
        let library = Library.shared
        // Site document order: preface, the 32 chapters, appendix, signatories.
        var rows: [ReaderRow] = [.hero]
        func apparatus(_ prefix: String, _ kicker: String, _ section: Apparatus.Section) {
            rows.append(.sectionHeader(kicker: kicker, title: section.title, anchor: prefix))
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
        ZStack(alignment: .top) {
            Theme.paper(scheme).ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.rows) { row in
                        rowView(row)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: 700, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, 52)
            }
            .scrollPosition(id: $scrollID, anchor: .top)
            .scrollIndicators(.hidden)

            TopBar(showSearch: $showSearch, showContents: $showContents, scrollTo: scrollTo)
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
            switch UserDefaults.standard.string(forKey: "seedOverlay") {
            case "contents": DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showContents = true }
            case "search": DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showSearch = true }
            default: break
            }
            #endif
            guard let position = store.position, position != "top" else {
                store.restoring = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                scrollID = position
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                store.restoring = false
            }
        }
        .fullScreenCover(isPresented: $showContents) {
            ContentsSheet(scrollTo: scrollTo)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(scrollTo: scrollTo)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func rowView(_ row: ReaderRow) -> some View {
        switch row {
        case .hero:
            HeroView(scrollTo: scrollTo)
        case .sectionHeader(let kicker, let title, _):
            SectionHeaderView(kicker: kicker, title: title)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.3)) { scrollID = id }
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
    let scrollTo: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button { scrollTo("top") } label: {
                (Text("1689").foregroundColor(Theme.ink(scheme))
                 + Text(".").foregroundColor(Theme.red))
                    .font(Fonts.sans(21, weight: 700))
            }
            .buttonStyle(.plain)

            Spacer()

            barButton("magnifyingglass", label: "Search") { showSearch = true }
            barButton(scheme == .dark ? "sun.max" : "moon",
                      label: scheme == .dark ? "Switch to light mode" : "Switch to candlelight") {
                store.darkOverride = !(scheme == .dark)
            }
            barButton("line.3.horizontal", label: "Contents and settings") { showContents = true }
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
    @Environment(\.colorScheme) private var scheme
    let scrollTo: (String) -> Void
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
                .padding(.bottom, 40)
        }
    }

    private var todayRow: some View {
        let id = library.todayParagraphID()
        let label = library.label(for: id)
        let title = library.paragraph(for: id)?.chapter.title ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            Text("Today's Reading")
                .font(Fonts.sans(11, weight: 600))
                .kerning(1.5)
                .textCase(.uppercase)
                .foregroundColor(Theme.inkSoft(scheme))
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
