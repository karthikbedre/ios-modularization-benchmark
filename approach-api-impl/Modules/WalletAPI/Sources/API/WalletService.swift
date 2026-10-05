import CoreModels
import SwiftUI

public protocol WalletService: SummaryProviding {
    func balance() async throws -> Money
    func paymentMethods() async throws -> [PaymentMethod]
    func transactions() async throws -> [WalletTransaction]
    /// Pays with the given method, or the default method when `methodID` is nil.
    func pay(_ request: PaymentRequest, methodID: String?) async throws -> PaymentReceipt
    /// Moves money from a debit or credit card onto the city card balance.
    func topUp(_ amount: Money, fromMethodID methodID: String) async throws -> Money
}

/// Screens other domains can present without importing the Wallet implementation.
public struct WalletEntryPoints: Sendable {
    public typealias Completion = @MainActor @Sendable (PaymentReceipt) -> Void

    public var checkout: @MainActor @Sendable (PaymentRequest, @escaping Completion) -> AnyView

    public init(checkout: @escaping @MainActor @Sendable (PaymentRequest, @escaping Completion) -> AnyView) {
        self.checkout = checkout
    }
}
