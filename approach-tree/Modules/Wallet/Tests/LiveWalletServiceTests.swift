import CoreModels
@testable import Wallet
import Wallet
import Testing

struct LiveWalletServiceTests {
    private let repository = InMemoryWalletRepository(snapshot: WalletFixtures.snapshot(balanceCents: 2000))
    private var service: LiveWalletService { WalletFixtures.service(repository: repository) }

    @Test func cityCardPaymentDrawsDownBalanceAndRecordsTransaction() async throws {
        let receipt = try await service.pay(PaymentRequest(merchant: "Metro", category: .transit, amount: .usd(2.75)), methodID: nil)

        #expect(receipt.paymentMethod == WalletFixtures.cityCard)
        #expect(receipt.remainingBalance == Money(minorUnits: 1725))
        #expect(receipt.payerName == "Sam Lee")
        let recorded = try #require(await repository.snapshot.transactions.first { $0.id == "tx-new" })
        #expect(recorded.amount == Money(minorUnits: -275))
        #expect(recorded.date == WalletFixtures.now)
    }

    @Test func paymentPostsReceiptNotification() async throws {
        let notifications = RecordingNotificationsService()
        let service = WalletFixtures.service(repository: repository, notifications: notifications)

        _ = try await service.pay(PaymentRequest(merchant: "Metro", category: .transit, amount: .usd(2.75)), methodID: nil)

        let posted = await notifications.posted
        #expect(posted.map(\.title) == ["Payment to Metro"])
        #expect(posted.first?.category == .payment)
    }

    @Test func failedPaymentPostsNothing() async {
        let notifications = RecordingNotificationsService()
        let service = WalletFixtures.service(repository: repository, notifications: notifications)

        _ = try? await service.pay(PaymentRequest(merchant: "Arena", category: .tickets, amount: .usd(36)), methodID: "pm-city")

        #expect(await notifications.posted.isEmpty)
    }

    @Test func cityCardPaymentOverBalanceFailsWithoutChanges() async {
        await #expect(throws: WalletError.insufficientFunds(available: Money(minorUnits: 2000))) {
            try await service.pay(PaymentRequest(merchant: "Arena", category: .tickets, amount: .usd(36)), methodID: "pm-city")
        }
        #expect(await repository.snapshot == WalletFixtures.snapshot(balanceCents: 2000))
    }

    @Test func cardPaymentLeavesBalanceUntouched() async throws {
        let receipt = try await service.pay(PaymentRequest(merchant: "Arena", category: .tickets, amount: .usd(36)), methodID: "pm-debit")

        #expect(receipt.remainingBalance == Money(minorUnits: 2000))
        #expect(await repository.snapshot.transactions.count == WalletFixtures.transactions.count + 1)
    }

    @Test(arguments: [Money.zero, Money(minorUnits: -100)])
    func nonPositiveAmountsAreRejected(amount: Money) async {
        await #expect(throws: WalletError.invalidAmount) {
            try await service.pay(PaymentRequest(merchant: "Metro", category: .transit, amount: amount), methodID: nil)
        }
    }

    @Test func unknownMethodIsRejected() async {
        await #expect(throws: WalletError.unknownPaymentMethod) {
            try await service.pay(PaymentRequest(merchant: "Metro", category: .transit, amount: .usd(1)), methodID: "missing")
        }
    }

    @Test func topUpFromCardIncreasesBalance() async throws {
        let balance = try await service.topUp(.usd(20), fromMethodID: "pm-debit")

        #expect(balance == Money(minorUnits: 4000))
        #expect(await repository.snapshot.transactions.last?.category == .topUp)
    }

    @Test func topUpFromCityCardIsRejected() async {
        await #expect(throws: WalletError.topUpRequiresCard) {
            try await service.topUp(.usd(20), fromMethodID: "pm-city")
        }
    }

    @Test func concurrentPaymentsCannotOverdrawTheBalance() async {
        let service = service
        let request = PaymentRequest(merchant: "Metro", category: .transit, amount: .usd(5))

        let successes = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { (try? await service.pay(request, methodID: "pm-city")) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        #expect(successes == 4)
        #expect(await repository.snapshot.balance == .zero)
    }

    @Test func listsAreSortedForDisplay() async throws {
        #expect(try await service.paymentMethods().first == WalletFixtures.cityCard)
        #expect(try await service.transactions().map(\.id) == ["t1", "t2", "t3", "t4"])
    }
}
