import SwiftUI

// The site's voice at wrist size: ink field (watch OLED), paper serif text,
// the constant blood red for structure.
enum WTheme {
    static let red = Color(red: 0x8A / 255, green: 0x10 / 255, blue: 0x16 / 255)
    static let redBright = Color(red: 0xAD / 255, green: 0x16 / 255, blue: 0x20 / 255)
    static let paper = Color(red: 0xE9 / 255, green: 0xE7 / 255, blue: 0xE3 / 255)
    static let soft = Color(red: 0x9A / 255, green: 0x97 / 255, blue: 0x93 / 255)

    static func serif(_ size: CGFloat, weight: Int = 400) -> Font {
        switch weight {
        case ..<450: return .custom("EBGaramond-Regular", size: size)
        case ..<550: return .custom("EBGaramond-Medium", size: size)
        default: return .custom("EBGaramond-SemiBold", size: size)
        }
    }
    static func sans(_ size: CGFloat, weight: Int = 500) -> Font {
        switch weight {
        case ..<550: return .custom("InstrumentSans-Medium", size: size)
        case ..<650: return .custom("InstrumentSans-SemiBold", size: size)
        default: return .custom("InstrumentSans-Bold", size: size)
        }
    }
}

@main
struct ConfessionWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchTodayView()
            }
        }
    }
}

struct WatchTodayView: View {
    private let library = Library.shared

    var body: some View {
        let id = library.todayParagraphID()
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Reading")
                    .font(WTheme.sans(11, weight: 600))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(WTheme.red)

                if let found = library.paragraph(for: id) {
                    Text("Chapter \(found.chapter.roman) · ¶ \(found.paragraph.number)")
                        .font(WTheme.sans(12, weight: 600))
                        .foregroundStyle(WTheme.soft)
                    Text(found.chapter.title)
                        .font(WTheme.serif(18, weight: 500))
                        .foregroundStyle(WTheme.paper)

                    Rectangle().fill(WTheme.red).frame(width: 28, height: 2)
                        .padding(.vertical, 4)

                    Text(found.paragraph.text)
                        .font(WTheme.serif(16))
                        .lineSpacing(4)
                        .foregroundStyle(WTheme.paper)
                }

                NavigationLink {
                    WatchChaptersView()
                } label: {
                    Text("All Chapters")
                        .font(WTheme.sans(13, weight: 600))
                        .foregroundStyle(WTheme.redBright)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .navigationTitle {
            (Text("1689").foregroundStyle(WTheme.paper) + Text(".").foregroundStyle(WTheme.red))
                .font(WTheme.sans(15, weight: 700))
        }
    }
}

struct WatchChaptersView: View {
    private let library = Library.shared

    var body: some View {
        List(library.confession.chapters) { chapter in
            NavigationLink {
                WatchChapterReader(chapter: chapter)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(chapter.roman)
                        .font(WTheme.sans(12, weight: 600))
                        .foregroundStyle(WTheme.red)
                        .frame(width: 34, alignment: .leading)
                    Text(chapter.title)
                        .font(WTheme.serif(14))
                        .foregroundStyle(WTheme.paper)
                        .lineLimit(2)
                }
            }
        }
        .navigationTitle("Chapters")
    }
}

struct WatchChapterReader: View {
    let chapter: Chapter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chapter \(chapter.roman)")
                    .font(WTheme.sans(11, weight: 600))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(WTheme.red)
                Text(chapter.title)
                    .font(WTheme.serif(18, weight: 500))
                    .foregroundStyle(WTheme.paper)

                ForEach(chapter.paragraphs, id: \.number) { paragraph in
                    (Text("\(paragraph.number)  ")
                        .font(WTheme.sans(11, weight: 600))
                        .foregroundStyle(WTheme.red)
                     + Text(paragraph.text)
                        .font(WTheme.serif(15))
                        .foregroundStyle(WTheme.paper))
                        .lineSpacing(4)
                }
            }
        }
        .navigationTitle("Chapter \(chapter.roman)")
    }
}
