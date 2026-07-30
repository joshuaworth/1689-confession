import SwiftUI

/// One quiet typographic frame on first launch. No tour, no carousel, no account.
struct FirstRunView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dismiss: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.paper(scheme).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                (Text("1689").foregroundColor(Theme.ink(scheme))
                 + Text(".").foregroundColor(Theme.red))
                    .font(Fonts.sans(46, weight: 700))
                    .padding(.bottom, 26)

                Rectangle().fill(Theme.red).frame(width: 44, height: 2)
                    .padding(.bottom, 26)

                Text("The whole confession,\nevery proof opened,\nnothing asked of you.")
                    .font(Fonts.serif(30, weight: 500))
                    .lineSpacing(6)
                    .foregroundColor(Theme.ink(scheme))
                    .padding(.bottom, 22)

                Text("No account. No ads. No tracking. Works offline. The text is public domain, and this is a gift.")
                    .font(Fonts.sans(15))
                    .lineSpacing(5)
                    .foregroundColor(Theme.inkSoft(scheme))

                Spacer()

                Button(action: dismiss) {
                    Text("Begin reading  →")
                        .font(Fonts.sans(15, weight: 600))
                        .foregroundColor(Theme.paper(scheme))
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(Theme.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { shown = true }
        }
    }
}
