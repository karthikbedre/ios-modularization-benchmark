import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications

public struct LiveWalletService: WalletService {
    private let repository: any WalletRepository
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any WalletRepository,
        identity: any IdentityService,
        notifications: any NotificationsService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { "tx-\(UUID().uuidString.prefix(8))" }
    ) {
        self.repository = repository
        self.identity = identity
        self.notifications = notifications
        self.dates = dates
        self.makeID = makeID
    }

    public func balance() async throws -> Money {
        try await repository.load().balance
    }

    public func paymentMethods() async throws -> [PaymentMethod] {
        try await repository.load().paymentMethods.sorted { $0.isDefault && !$1.isDefault }
    }

    public func transactions() async throws -> [WalletTransaction] {
        try await repository.load().transactions.sorted { $0.date > $1.date }
    }

    public func pay(_ request: PaymentRequest, methodID: String?) async throws -> PaymentReceipt {
        guard request.amount.isPositive else { throw WalletError.invalidAmount }
        let payerName = (try? await identity.currentUser().fullName) ?? "City resident"
        let id = makeID()
        let date = dates.now

        let receipt = try await repository.update { snapshot in
            let method = try Self.resolveMethod(methodID, in: snapshot)
            if method.kind == .cityCard {
                guard snapshot.balance >= request.amount else {
                    throw WalletError.insufficientFunds(available: snapshot.balance)
                }
                snapshot.balance = snapshot.balance - request.amount
            }
            snapshot.transactions.append(WalletTransaction(
                id: id,
                merchant: request.merchant,
                category: request.category,
                amount: Money.zero - request.amount,
                date: date,
                paymentMethodID: method.id,
                reference: request.reference
            ))
            return PaymentReceipt(
                transactionID: id,
                merchant: request.merchant,
                amount: request.amount,
                date: date,
                paymentMethod: method,
                payerName: payerName,
                remainingBalance: snapshot.balance
            )
        }
        // The payment already went through, so a failed receipt notification must not fail it.
        _ = try? await notifications.post(NotificationDraft(
            title: "Payment to \(receipt.merchant)",
            body: "\(receipt.amount.formatted) paid with \(receipt.paymentMethod.displayName).",
            category: .payment,
            sourceDomain: "Wallet"
        ))
        return receipt
    }

    public func topUp(_ amount: Money, fromMethodID methodID: String) async throws -> Money {
        guard amount.isPositive else { throw WalletError.invalidAmount }
        let id = makeID()
        let date = dates.now

        return try await repository.update { snapshot in
            let method = try Self.resolveMethod(methodID, in: snapshot)
            guard method.kind != .cityCard else { throw WalletError.topUpRequiresCard }
            snapshot.balance = snapshot.balance + amount
            snapshot.transactions.append(WalletTransaction(
                id: id,
                merchant: "City Card top up",
                category: .topUp,
                amount: amount,
                date: date,
                paymentMethodID: method.id
            ))
            return snapshot.balance
        }
    }

    public func summary() async -> DomainSummary {
        guard let balance = try? await balance() else {
            return DomainSummary(title: "Wallet", detail: "Balance unavailable")
        }
        return DomainSummary(title: "Wallet", detail: "City Card balance \(balance.formatted)")
    }

    private static func resolveMethod(_ id: String?, in snapshot: WalletSnapshot) throws(WalletError) -> PaymentMethod {
        let method = if let id {
            snapshot.paymentMethods.first { $0.id == id }
        } else {
            snapshot.paymentMethods.first(where: \.isDefault)
        }
        guard let method else { throw .unknownPaymentMethod }
        return method
    }
}
