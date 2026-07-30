import UIKit
import PDFKit

/// Typeset export, for readers who study on paper. The page is set in the
/// app's own fonts with the same measure and the same red, so a printed
/// chapter is recognisably from the same edition as the screen.
enum PDFExport {
    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter
    private static let margin: CGFloat = 72

    static func chapter(_ chapter: Chapter) -> URL? {
        render(title: "Chapter \(chapter.roman)",
               subtitle: chapter.title,
               blocks: chapter.paragraphs.map { ("\($0.number)", $0.text, $0.proofs) },
               filename: "1689-chapter-\(chapter.number).pdf")
    }

    static func whole() -> URL? {
        var blocks: [(String, String, String)] = []
        for chapter in Library.shared.confession.chapters {
            blocks.append(("", "Chapter \(chapter.roman) — \(chapter.title)", ""))
            for paragraph in chapter.paragraphs {
                blocks.append(("\(paragraph.number)", paragraph.text, paragraph.proofs))
            }
        }
        return render(title: "The Baptist Confession of Faith",
                      subtitle: "The Second London Baptist Confession · 1689",
                      blocks: blocks,
                      filename: "1689-confession.pdf")
    }

    private static func render(title: String, subtitle: String,
                               blocks: [(String, String, String)], filename: String) -> URL? {
        let serif = UIFont(name: "EBGaramond-Regular", size: 11) ?? .systemFont(ofSize: 11)
        let serifDisplay = UIFont(name: "EBGaramond-Medium", size: 22) ?? .boldSystemFont(ofSize: 22)
        let sans = UIFont(name: "InstrumentSans-SemiBold", size: 8) ?? .systemFont(ofSize: 8)
        let red = UIColor(red: 0x8A / 255, green: 0x10 / 255, blue: 0x16 / 255, alpha: 1)
        let ink = UIColor(red: 0x1C / 255, green: 0x1B / 255, blue: 0x1A / 255, alpha: 1)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        do {
            try renderer.writePDF(to: url) { context in
                var y = margin
                let width = pageSize.width - margin * 2
                context.beginPage()

                func newPageIfNeeded(_ height: CGFloat) {
                    if y + height > pageSize.height - margin {
                        context.beginPage()
                        y = margin
                    }
                }

                func draw(_ string: NSAttributedString, indent: CGFloat = 0) {
                    let bounds = string.boundingRect(
                        with: CGSize(width: width - indent, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    newPageIfNeeded(bounds.height)
                    string.draw(with: CGRect(x: margin + indent, y: y, width: width - indent,
                                             height: bounds.height),
                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    y += bounds.height + 8
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 3

                draw(NSAttributedString(string: subtitle.uppercased(), attributes: [
                    .font: sans, .foregroundColor: red, .kern: 1.4]))
                draw(NSAttributedString(string: title, attributes: [
                    .font: serifDisplay, .foregroundColor: red]))
                y += 10

                for (number, text, proofs) in blocks {
                    if number.isEmpty {
                        y += 14
                        draw(NSAttributedString(string: text, attributes: [
                            .font: serifDisplay, .foregroundColor: red]))
                        continue
                    }
                    let body = NSMutableAttributedString(
                        string: "\(number)  ",
                        attributes: [.font: sans, .foregroundColor: red])
                    body.append(NSAttributedString(string: text, attributes: [
                        .font: serif, .foregroundColor: ink, .paragraphStyle: paragraphStyle]))
                    if !proofs.isEmpty {
                        body.append(NSAttributedString(string: "  (\(proofs))", attributes: [
                            .font: sans, .foregroundColor: red]))
                    }
                    draw(body)
                }

                y += 16
                draw(NSAttributedString(string: "The text is in the public domain. 1689.intentmesh.dev",
                                        attributes: [.font: sans, .foregroundColor: ink.withAlphaComponent(0.6)]))
            }
            return url
        } catch {
            return nil
        }
    }
}
