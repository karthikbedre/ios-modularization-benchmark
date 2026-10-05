import CoreModels
import DesignSystem
import SwiftUI

struct WalletHomeScreen: View {
    @State private var viewModel: WalletHomeViewModel

    init(service: any WalletService) {
        _viewModel = State(initialValue: WalletHomeViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { content in
            List {
                Section {
                    BalanceCard(balance: content.balance)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    NavigationLink(value: WalletRoute.addFunds) {
                        Label("Add funds", systemImage: "plus.circle")
                    }
                }
                Section("Payment methods") {
                    ForEach(content.paymentMethods) { method in
                        PaymentMethodRow(method: method)
                    }
                }
                if !content.spending.entries.isEmpty {
                    Section("Spending") {
                        SpendingBreakdownView(breakdown: content.spending)
                    }
                }
                Section {
                    ForEach(content.recentTransactions) { transaction in
                        NavigationLink(value: WalletRoute.transaction(transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                    NavigationLink("See all transactions", value: WalletRoute.transactions)
                } header: {
                    Text("Recent")
                }
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Wallet")
        .navigationDestination(for: WalletRoute.self) { route in
            switch route {
            case .transactions:
                TransactionsScreen(service: viewModel.service)
            case .transaction(let transaction):
                TransactionDetailScreen(transaction: transaction)
            case .addFunds:
                AddFundsScreen(service: viewModel.service) {
                    Task { await viewModel.load() }
                }
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

#Preview {
    NavigationStack {
        WalletHomeScreen(service: PreviewWalletService())
    }
}
