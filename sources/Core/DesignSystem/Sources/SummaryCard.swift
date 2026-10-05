import CoreModels
import SwiftUI

public struct SummaryCard: View {
    private let summary: DomainSummary

    public init(summary: DomainSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(summary.title)
                .font(.headline)
            Text(summary.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

#Preview {
    SummaryCard(summary: DomainSummary(title: "Wallet", detail: "2 cards"))
        .padding()
}
