
extension WalletError {
    var message: String {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        case .insufficientFunds(let available): "Not enough on your City Card. Available: \(available.formatted)."
        case .unknownPaymentMethod: "Choose a payment method."
        case .topUpRequiresCard: "Top ups must come from a debit or credit card."
        }
    }
}

extension TransactionCategory {
    var systemImage: String {
        switch self {
        case .transit: "tram.fill"
        case .parking: "parkingsign.circle.fill"
        case .tickets: "ticket.fill"
        case .dining: "fork.knife"
        case .utilities: "bolt.fill"
        case .topUp: "arrow.down.circle.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}
