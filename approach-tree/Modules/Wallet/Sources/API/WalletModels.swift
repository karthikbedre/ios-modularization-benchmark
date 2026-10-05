import CoreModels
import Foundation

public struct PaymentMethod: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Hashable, Sendable, Codable {
        /// Prepaid city card. Payments draw down the wallet balance.
        case cityCard
        case debitCard
        case creditCard
    }

    public var id: String
    public var kind: Kind
    public var label: String
    public var last4: String
    public var isDefault: Bool

    public init(id: String, kind: Kind, label: String, last4: String, isDefault: Bool) {
        self.id = id
        self.kind = kind
        self.label = label
        self.last4 = last4
        self.isDefault = isDefault
    }

    public var displayName: String {
        "\(label) •••• \(last4)"
    }
}

public enum TransactionCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case transit, parking, tickets, dining, utilities, topUp, other

    public var title: String {
        switch self {
        case .transit: "Transit"
        case .parking: "Parking"
        case .tickets: "Tickets"
        case .dining: "Dining"
        case .utilities: "Utilities"
        case .topUp: "Top up"
        case .other: "Other"
        }
    }
}

public struct WalletTransaction: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var merchant: String
    public var category: TransactionCategory
    /// Negative for spending, positive for top ups and refunds.
    public var amount: Money
    public var date: Date
    public var paymentMethodID: String
    public var reference: String?

    public init(id: String, merchant: String, category: TransactionCategory, amount: Money, date: Date, paymentMethodID: String, reference: String? = nil) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.date = date
        self.paymentMethodID = paymentMethodID
        self.reference = reference
    }
}

public struct PaymentRequest: Hashable, Sendable {
    public var merchant: String
    public var category: TransactionCategory
    public var amount: Money
    public var reference: String?

    public init(merchant: String, category: TransactionCategory, amount: Money, reference: String? = nil) {
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.reference = reference
    }
}

public struct PaymentReceipt: Hashable, Sendable {
    public var transactionID: String
    public var merchant: String
    public var amount: Money
    public var date: Date
    public var paymentMethod: PaymentMethod
    public var payerName: String
    public var remainingBalance: Money

    public init(transactionID: String, merchant: String, amount: Money, date: Date, paymentMethod: PaymentMethod, payerName: String, remainingBalance: Money) {
        self.transactionID = transactionID
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.payerName = payerName
        self.remainingBalance = remainingBalance
    }
}

public enum WalletError: Error, Hashable, Sendable {
    case invalidAmount
    case insufficientFunds(available: Money)
    case unknownPaymentMethod
    case topUpRequiresCard
}
