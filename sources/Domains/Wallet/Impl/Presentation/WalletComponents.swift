import CoreModels
import DesignSystem
import SwiftUI
import WalletAPI

struct BalanceCard: View {
    let balance: Money

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("City Card balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Text(balance.formatted)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.large)
        .background(
            LinearGradient(colors: [Palette.accent, Palette.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
    }
}

struct PaymentMethodRow: View {
    let method: PaymentMethod

    var body: some View {
        HStack {
            Image(systemName: method.kind == .cityCard ? "building.columns.fill" : "creditcard.fill")
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            Text(method.displayName)
            Spacer()
            if method.isDefault {
                StatusBadge("Default")
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: WalletTransaction

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: transaction.category.systemImage)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                Text(transaction.reference ?? transaction.category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AmountText(transaction.amount, showsSign: true)
        }
    }
}

struct SpendingBreakdownView: View {
    let breakdown: SpendingBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(breakdown.entries.prefix(4), id: \.category) { entry in
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text(entry.category.title)
                        Spacer()
                        AmountText(entry.total)
                    }
                    .font(.subheadline)
                    ProgressView(value: share(of: entry.total))
                        .tint(Palette.accent)
                }
            }
        }
        .padding(.vertical, Spacing.small)
    }

    private func share(of money: Money) -> Double {
        guard breakdown.total.isPositive else { return 0 }
        return Double(money.minorUnits) / Double(breakdown.total.minorUnits)
    }
}
