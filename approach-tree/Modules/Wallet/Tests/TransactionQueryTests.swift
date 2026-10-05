import CoreModels
import Foundation
@testable import Wallet
import Wallet
import Testing

struct TransactionQueryTests {
    private let transactions = WalletFixtures.transactions

    @Test func filtersByCategory() {
        let query = TransactionQuery(category: .parking)

        #expect(query.apply(to: transactions).map(\.id) == ["t2"])
    }

    @Test func searchMatchesMerchantOrReferenceCaseInsensitively() {
        #expect(TransactionQuery(searchText: "noodle").apply(to: transactions).map(\.id) == ["t4"])
        #expect(TransactionQuery(searchText: "zone r4").apply(to: transactions).map(\.id) == ["t2"])
        #expect(TransactionQuery(searchText: "  ").apply(to: transactions).count == transactions.count)
    }

    @Test func groupsByDayNewestFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        let days = TransactionDay.group(transactions, calendar: calendar)

        #expect(days.map { $0.transactions.map(\.id) } == [["t1"], ["t2", "t3"], ["t4"]])
        #expect(days[1].total == Money(minorUnits: 3100))
    }

    @Test func spendingBreakdownExcludesTopUpsAndSortsLargestFirst() {
        let breakdown = SpendingBreakdown(transactions)

        #expect(breakdown.entries.map(\.category) == [.dining, .parking, .transit])
        #expect(breakdown.total == Money(minorUnits: 3020))
    }
}
