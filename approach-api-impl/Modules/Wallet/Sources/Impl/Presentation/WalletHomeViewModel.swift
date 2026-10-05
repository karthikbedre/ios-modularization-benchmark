import CoreKit
import CoreModels
import Observation
import WalletAPI

@MainActor
@Observable
final class WalletHomeViewModel {
    struct Content: Equatable {
        var balance: Money
        var paymentMethods: [PaymentMethod]
        var recentTransactions: [WalletTransaction]
        var spending: SpendingBreakdown
    }

    private(set) var state: LoadState<Content> = .idle
    let service: any WalletService

    init(service: any WalletService) {
        self.service = service
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let balance = service.balance()
            async let methods = service.paymentMethods()
            async let transactions = service.transactions()
            let allTransactions = try await transactions
            state = .loaded(Content(
                balance: try await balance,
                paymentMethods: try await methods,
                recentTransactions: Array(allTransactions.prefix(5)),
                spending: SpendingBreakdown(allTransactions)
            ))
        } catch {
            state = .failed("Your wallet could not be loaded.")
        }
    }
}
