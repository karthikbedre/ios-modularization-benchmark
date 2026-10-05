import CoreModels
import Foundation

struct TransactionQuery: Hashable, Sendable {
    var searchText = ""
    var category: TransactionCategory?

    func apply(to transactions: [WalletTransaction]) -> [WalletTransaction] {
        let needle = searchText.trimmingCharacters(in: .whitespaces)
        return transactions.filter { transaction in
            let matchesCategory = category.map { $0 == transaction.category } ?? true
            let matchesText = needle.isEmpty
                || transaction.merchant.localizedStandardContains(needle)
                || (transaction.reference?.localizedStandardContains(needle) ?? false)
            return matchesCategory && matchesText
        }
    }
}

struct TransactionDay: Identifiable, Hashable, Sendable {
    var day: Date
    var transactions: [WalletTransaction]

    var id: Date { day }

    var total: Money {
        transactions.reduce(.zero) { $0 + $1.amount }
    }

    /// Groups by calendar day, newest day first and newest transaction first within a day.
    static func group(_ transactions: [WalletTransaction], calendar: Calendar = .current) -> [TransactionDay] {
        Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .map { TransactionDay(day: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}

struct SpendingBreakdown: Hashable, Sendable {
    struct Entry: Hashable, Sendable {
        var category: TransactionCategory
        var total: Money
    }

    var entries: [Entry]

    var total: Money {
        entries.reduce(.zero) { $0 + $1.total }
    }

    /// Spending only. Top ups and refunds are excluded. Largest category first.
    init(_ transactions: [WalletTransaction]) {
        let spending = transactions.filter { !$0.amount.isPositive }
        entries = Dictionary(grouping: spending, by: \.category)
            .map { Entry(category: $0.key, total: $0.value.reduce(.zero) { $0 - $1.amount }) }
            .sorted { $0.total > $1.total }
    }
}
