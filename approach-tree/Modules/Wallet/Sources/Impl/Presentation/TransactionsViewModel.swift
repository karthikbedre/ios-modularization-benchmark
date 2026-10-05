import CoreKit
import Observation

@MainActor
@Observable
final class TransactionsViewModel {
    private(set) var state: LoadState<[WalletTransaction]> = .idle
    var query = TransactionQuery()

    private let service: any WalletService

    init(service: any WalletService) {
        self.service = service
    }

    var days: [TransactionDay] {
        TransactionDay.group(query.apply(to: state.value ?? []))
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await service.transactions())
        } catch {
            state = .failed("Transactions could not be loaded.")
        }
    }
}
