import CoreKit
import CoreModels
import Observation
import WalletAPI

@MainActor
@Observable
final class CheckoutViewModel {
    let request: PaymentRequest
    private(set) var methods: LoadState<[PaymentMethod]> = .idle
    private(set) var balance: Money?
    var selectedMethodID: String?
    private(set) var receipt: PaymentReceipt?
    private(set) var errorMessage: String?
    private(set) var isPaying = false

    private let service: any WalletService

    init(request: PaymentRequest, service: any WalletService) {
        self.request = request
        self.service = service
    }

    var selectedMethod: PaymentMethod? {
        methods.value?.first { $0.id == selectedMethodID }
    }

    /// Warns before paying instead of failing, when the City Card cannot cover the amount.
    var coversAmount: Bool {
        guard selectedMethod?.kind == .cityCard, let balance else { return true }
        return balance >= request.amount
    }

    func load() async {
        methods = .loading
        do {
            async let loadedMethods = service.paymentMethods()
            async let loadedBalance = service.balance()
            let all = try await loadedMethods
            balance = try await loadedBalance
            methods = .loaded(all)
            selectedMethodID = selectedMethodID ?? all.first(where: \.isDefault)?.id ?? all.first?.id
        } catch {
            methods = .failed("Payment methods could not be loaded.")
        }
    }

    func pay() async {
        isPaying = true
        defer { isPaying = false }
        do {
            receipt = try await service.pay(request, methodID: selectedMethodID)
            errorMessage = nil
        } catch let error as WalletError {
            errorMessage = error.message
        } catch {
            errorMessage = "The payment did not go through."
        }
    }
}
