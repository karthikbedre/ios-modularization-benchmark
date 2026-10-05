import DesignSystem
import SwiftUI

struct TransactionsScreen: View {
    @State private var viewModel: TransactionsViewModel

    init(service: any WalletService) {
        _viewModel = State(initialValue: TransactionsViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { _ in
            let days = viewModel.days
            if days.isEmpty {
                EmptyStateView("No transactions", systemImage: "magnifyingglass", message: "Try a different search or category.")
            } else {
                List(days) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            NavigationLink(value: WalletRoute.transaction(transaction)) {
                                TransactionRow(transaction: transaction)
                            }
                        }
                    } header: {
                        HStack {
                            Text(day.day.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            AmountText(day.total, showsSign: true)
                        }
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .searchable(text: $viewModel.query.searchText, prompt: "Merchant or reference")
        .toolbar {
            Menu {
                Picker("Category", selection: $viewModel.query.category) {
                    Text("All categories").tag(TransactionCategory?.none)
                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                        Label(category.title, systemImage: category.systemImage).tag(Optional(category))
                    }
                }
            } label: {
                Label("Filter", systemImage: viewModel.query.category == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsScreen(service: PreviewWalletService())
            .navigationDestination(for: WalletRoute.self) { _ in EmptyView() }
    }
}
