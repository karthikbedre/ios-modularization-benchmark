import CoreModels
import Foundation
import Observation

@MainActor
@Observable
final class AddFundsViewModel {
    static let presets: [Money] = [.usd(10), .usd(20), .usd(50), .usd(100)]

    var amountText = ""
    var selectedMethodID: String?
    private(set) var fundingMethods: [PaymentMethod] = []
    private(set) var errorMessage: String?
    private(set) var newBalance: Money?
    private(set) var isSubmitting = false

    private let service: any WalletService

    init(service: any WalletService) {
        self.service = service
    }

    var amount: Money? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespaces)).map { Money.usd($0) }
    }

    var canSubmit: Bool {
        (amount?.isPositive ?? false) && selectedMethodID != nil && !isSubmitting
    }

    func selectPreset(_ money: Money) {
        amountText = "\(money.amount)"
    }

    func load() async {
        let methods = (try? await service.paymentMethods()) ?? []
        fundingMethods = methods.filter { $0.kind != .cityCard }
        selectedMethodID = selectedMethodID ?? fundingMethods.first?.id
    }

    func submit() async {
        guard let amount, let selectedMethodID else {
            errorMessage = WalletError.invalidAmount.message
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            newBalance = try await service.topUp(amount, fromMethodID: selectedMethodID)
            errorMessage = nil
        } catch let error as WalletError {
            errorMessage = error.message
        } catch {
            errorMessage = "The top up did not go through."
        }
    }
}
