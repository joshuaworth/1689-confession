import WidgetKit
import SwiftUI
import UIKit

// MARK: - Minimal data (widget bundles its own copy of the confession)

private struct WConfession: Decodable {
    let chapters: [WChapter]
}
private struct WChapter: Decodable {
    let number: Int
    let title: String
    let paragraphs: [WParagraph]
}
private struct WParagraph: Decodable {
    let number: Int
    let text: String
}

private enum WLibrary {
    static let chapters: [WChapter] = {
        guard let url = Bundle.main.url(forResource: "confession", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let confession = try? JSONDecoder().decode(WConfession.self, from: data) else { return [] }
        return confession.chapters
    }()

    static func today(for date: Date) -> (chapter: WChapter, paragraph: WParagraph)? {
        let order = chapters.flatMap { ch in ch.paragraphs.map { (ch, $0) } }
        guard !order.isEmpty else { return nil }
        let days = Int(date.timeIntervalSince1970 / 86_400)
        return order[days % order.count]
    }

    static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                                      (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (value, glyph) in table { while n >= value { out += glyph; n -= value } }
        return out
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let kicker: String
    let title: String
    let text: String
}

struct TodayProvider: TimelineProvider {
    func entry(for date: Date) -> TodayEntry {
        guard let found = WLibrary.today(for: date) else {
            return TodayEntry(date: date, kicker: "1689", title: "The Baptist Confession",
                              text: "Open the app to read today's paragraph.")
        }
        return TodayEntry(date: date,
                          kicker: "Chapter \(WLibrary.roman(found.chapter.number)) · ¶ \(found.paragraph.number)",
                          title: found.chapter.title,
                          text: found.paragraph.text)
    }

    func placeholder(in context: Context) -> TodayEntry { entry(for: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(entry(for: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        completion(Timeline(entries: [entry(for: now)], policy: .after(midnight)))
    }
}

// MARK: - Views

private let wRed = Color(red: 0x8A / 255, green: 0x10 / 255, blue: 0x16 / 255)

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("1689 · \(entry.kicker)")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("1689 · Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.kicker)
                        .font(.system(size: 13, weight: .bold))
                    Text(entry.title)
                        .font(.system(size: 12, design: .serif))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Reading")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(entry.kicker)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(wRed)
                    Text(entry.title)
                        .font(.system(size: family == .systemSmall ? 12 : 14, weight: .medium, design: .serif))
                        .lineLimit(2)
                    if family != .systemSmall {
                        Text(entry.text)
                            .font(.system(size: 13, design: .serif))
                            .lineLimit(4)
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(URL(string: "confession1689://today"))
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}

@main
struct TodayWidgetBundle: WidgetBundle {
    var body: some Widget { TodayWidget() }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayReading", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Reading")
        .description("One paragraph a day through the whole confession.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}
