#if DEBUG
import CoreModels
import Foundation

extension PaymentMethod {
    public static let previewCityCard = PaymentMethod(id: "pm-city", kind: .cityCard, label: "City Card", last4: "0042", isDefault: true)
    public static let previewDebit = PaymentMethod(id: "pm-debit", kind: .debitCard, label: "Debit", last4: "7781", isDefault: false)
}

public struct PreviewWalletService: WalletService {
    public init() {}

    public func balance() async throws -> Money { .usd(54.20) }

    public func paymentMethods() async throws -> [PaymentMethod] {
        [.previewCityCard, .previewDebit]
    }

    public func transactions() async throws -> [WalletTransaction] {
        [
            WalletTransaction(id: "t1", merchant: "Metro Line 2", category: .transit, amount: .usd(-2.75), date: .now, paymentMethodID: "pm-city"),
            WalletTransaction(id: "t2", merchant: "Top up", category: .topUp, amount: .usd(40), date: .now.addingTimeInterval(-86_400), paymentMethodID: "pm-debit"),
        ]
    }

    public func pay(_ request: PaymentRequest, methodID: String?) async throws -> PaymentReceipt {
        PaymentReceipt(
            transactionID: "preview",
            merchant: request.merchant,
            amount: request.amount,
            date: .now,
            paymentMethod: .previewCityCard,
            payerName: "Avery Morgan",
            remainingBalance: .usd(54.20) - request.amount
        )
    }

    public func topUp(_ amount: Money, fromMethodID methodID: String) async throws -> Money {
        .usd(54.20) + amount
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Wallet", detail: "Balance \(Money.usd(54.20).formatted)")
    }
}
#endif
