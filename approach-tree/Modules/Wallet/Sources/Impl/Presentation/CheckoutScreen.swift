import DesignSystem
import SwiftUI

struct CheckoutScreen: View {
    @State private var viewModel: CheckoutViewModel
    private let onComplete: WalletEntryPoints.Completion

    init(request: PaymentRequest, service: any WalletService, onComplete: @escaping WalletEntryPoints.Completion) {
        _viewModel = State(initialValue: CheckoutViewModel(request: request, service: service))
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            if let receipt = viewModel.receipt {
                ReceiptView(receipt: receipt) { onComplete(receipt) }
            } else {
                AsyncContentView(state: viewModel.methods, retry: viewModel.load) { methods in
                    form(methods: methods)
                }
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .idle = viewModel.methods { await viewModel.load() }
        }
    }

    private func form(methods: [PaymentMethod]) -> some View {
        Form {
            Section("Order") {
                KeyValueRow("Merchant", value: viewModel.request.merchant)
                if let reference = viewModel.request.reference {
                    KeyValueRow("For", value: reference)
                }
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    AmountText(viewModel.request.amount).font(.headline)
                }
            }
            Section("Pay with") {
                Picker("Payment method", selection: $viewModel.selectedMethodID) {
                    ForEach(methods) { method in
                        Text(method.displayName).tag(Optional(method.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                if !viewModel.coversAmount, let balance = viewModel.balance {
                    Label("City Card balance is \(balance.formatted)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Palette.warning)
                }
            }
            if let message = viewModel.errorMessage {
                Section {
                    Text(message).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button("Pay \(viewModel.request.amount.formatted)") {
                    Task { await viewModel.pay() }
                }
                .buttonStyle(.primary)
                .disabled(viewModel.isPaying || !viewModel.coversAmount)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct ReceiptView: View {
    let receipt: PaymentReceipt
    let done: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.positive)
            Text("Paid \(receipt.amount.formatted)")
                .font(.title2.weight(.semibold))
            VStack(spacing: Spacing.small) {
                KeyValueRow("Merchant", value: receipt.merchant)
                KeyValueRow("Method", value: receipt.paymentMethod.displayName)
                KeyValueRow("City Card balance", value: receipt.remainingBalance.formatted)
            }
            .padding(Spacing.medium)
            .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            Button("Done", action: done)
                .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

#Preview {
    NavigationStack {
        CheckoutScreen(
            request: PaymentRequest(merchant: "Harbor Amphitheater", category: .tickets, amount: .usd(36), reference: "Autumn Jazz Night"),
            service: PreviewWalletService()
        ) { _ in }
    }
}
