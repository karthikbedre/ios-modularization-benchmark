import WalletAPI

enum WalletRoute: Hashable {
    case transactions
    case transaction(WalletTransaction)
    case addFunds
}
