import SwiftUI

struct SignatoriesView: View {
    @Environment(\.colorScheme) private var scheme
    let signatories: Apparatus.Signatories

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.rule(scheme)).frame(height: 1)
                .padding(.top, 44).padding(.bottom, 36)

            Text("The Ministers and Messengers")
                .font(Fonts.sans(12, weight: 600))
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundColor(Theme.red)
                .padding(.bottom, 8)

            Text(signatories.title)
                .font(Fonts.serif(32, weight: 500))
                .foregroundColor(Theme.red)
                .padding(.bottom, 16)

            Text(signatories.note)
                .font(Fonts.serif(16, italic: true))
                .lineSpacing(5)
                .foregroundColor(Theme.inkSoft(scheme))
                .padding(.bottom, 24)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading),
                                GridItem(.flexible(), alignment: .topLeading)],
                      alignment: .leading, spacing: 16) {
                ForEach(signatories.names) { signer in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signer.name)
                            .font(Fonts.serif(17))
                            .foregroundColor(Theme.ink(scheme))
                        if let church = signer.church {
                            Text([signer.role, church].compactMap { $0 }.joined(separator: " · "))
                                .font(Fonts.sans(12))
                                .foregroundColor(Theme.inkSoft(scheme))
                        }
                    }
                }
            }
            .padding(.bottom, 26)

            Text(signatories.subscription)
                .font(Fonts.serif(16, italic: true))
                .lineSpacing(5)
                .foregroundColor(Theme.inkSoft(scheme))
        }
        .id("signatories")
    }
}
