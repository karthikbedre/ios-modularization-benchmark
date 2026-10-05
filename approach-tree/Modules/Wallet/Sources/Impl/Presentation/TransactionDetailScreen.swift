import DesignSystem
import SwiftUI

struct TransactionDetailScreen: View {
    let transaction: WalletTransaction

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.small) {
                    Image(systemName: transaction.category.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(Palette.accent)
                    AmountText(transaction.amount, showsSign: true)
                        .font(.largeTitle.weight(.semibold))
                    Text(transaction.merchant)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.medium)
            }
            Section("Details") {
                KeyValueRow("Category", value: transaction.category.title)
                KeyValueRow("Date", value: transaction.date.formatted(date: .long, time: .shortened))
                if let reference = transaction.reference {
                    KeyValueRow("Reference", value: reference)
                }
                KeyValueRow("Transaction ID", value: transaction.id)
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}
