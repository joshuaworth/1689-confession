import SwiftUI
import UIKit

struct ShareCardItem: Identifiable {
    let id = UUID()
    let label: String
    let text: String
}

/// A typeset paper card of the paragraph, rendered natively for sharing.
struct ShareCardView: View {
    let item: ShareCardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            (Text("1689").foregroundColor(Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x1A / 255))
             + Text(".").foregroundColor(Theme.red))
                .font(Fonts.sans(30, weight: 700))

            Text(item.text)
                .font(Fonts.serif(24))
                .lineSpacing(9)
                .foregroundColor(Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x1A / 255))

            HStack {
                Rectangle().fill(Theme.red).frame(width: 34, height: 2)
                Text(item.label)
                    .font(Fonts.sans(14, weight: 600))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.red)
            }
        }
        .padding(44)
        .frame(width: 900, alignment: .leading)
        .background(Color(red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF7 / 255))
    }
}

struct ShareCardSheet: View {
    let item: ShareCardItem
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            if let rendered {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 14)
                    .padding(.horizontal, 24)

                ShareLink(item: Image(uiImage: rendered),
                          preview: SharePreview(item.label, image: Image(uiImage: rendered))) {
                    Label("Share Card", systemImage: "square.and.arrow.up")
                        .font(Fonts.sans(15, weight: 600))
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(Theme.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            } else {
                ProgressView()
            }
            Button("Done") { dismiss() }
                .font(Fonts.sans(14))
                .buttonStyle(.plain)
        }
        .padding(.vertical, 30)
        .presentationDetents([.medium, .large])
        .task {
            let renderer = ImageRenderer(content: ShareCardView(item: item))
            renderer.scale = 3
            rendered = renderer.uiImage
        }
    }
}
