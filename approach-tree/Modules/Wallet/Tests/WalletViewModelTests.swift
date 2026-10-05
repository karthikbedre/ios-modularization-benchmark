import CoreModels
@testable import Wallet
import Wallet
import Testing

@MainActor
struct WalletViewModelTests {
    private let repository = InMemoryWalletRepository(snapshot: WalletFixtures.snapshot(balanceCents: 2000))

    @Test func homeLoadsBalanceRecentTransactionsAndSpending() async {
        let viewModel = WalletHomeViewModel(service: WalletFixtures.service(repository: repository))

        await viewModel.load()

        let content = viewModel.state.value
        #expect(content?.balance == Money(minorUnits: 2000))
        #expect(content?.recentTransactions.first?.id == "t1")
        #expect(content?.spending.entries.first?.category == .dining)
    }

    @Test func checkoutDefaultsToCityCardAndBlocksWhenBalanceIsShort() async {
        let request = PaymentRequest(merchant: "Arena", category: .tickets, amount: .usd(36))
        let viewModel = CheckoutViewModel(request: request, service: WalletFixtures.service(repository: repository))

        await viewModel.load()

        #expect(viewModel.selectedMethodID == "pm-city")
        #expect(!viewModel.coversAmount)
        viewModel.selectedMethodID = "pm-debit"
        #expect(viewModel.coversAmount)
    }

    @Test func checkoutPaysAndExposesReceipt() async {
        let request = PaymentRequest(merchant: "Metro", category: .transit, amount: .usd(2.75))
        let viewModel = CheckoutViewModel(request: request, service: WalletFixtures.service(repository: repository))
        await viewModel.load()

        await viewModel.pay()

        #expect(viewModel.receipt?.remainingBalance == Money(minorUnits: 1725))
        #expect(viewModel.errorMessage == nil)
    }

    @Test func addFundsOnlyOffersCardsAndTopsUp() async {
        let viewModel = AddFundsViewModel(service: WalletFixtures.service(repository: repository))
        await viewModel.load()
        #expect(viewModel.fundingMethods.map(\.id) == ["pm-debit"])
        #expect(!viewModel.canSubmit)

        viewModel.selectPreset(.usd(20))
        await viewModel.submit()

        #expect(viewModel.newBalance == Money(minorUnits: 4000))
    }

    @Test func addFundsRejectsUnparseableAmount() async {
        let viewModel = AddFundsViewModel(service: WalletFixtures.service(repository: repository))
        await viewModel.load()
        viewModel.amountText = "abc"

        await viewModel.submit()

        #expect(viewModel.errorMessage == "Enter an amount greater than zero.")
        #expect(viewModel.newBalance == nil)
    }
}
