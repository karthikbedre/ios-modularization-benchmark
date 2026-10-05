import CoreModels
import DesignSystem
import SwiftUI
import WalletAPI

struct AddFundsScreen: View {
    @State private var viewModel: AddFundsViewModel
    @Environment(\.dismiss) private var dismiss
    private let onComplete: () -> Void

    init(service: any WalletService, onComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: AddFundsViewModel(service: service))
        self.onComplete = onComplete
    }

    var body: some View {
        Form {
            Section("Amount") {
                TextField("0.00", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                HStack {
                    ForEach(AddFundsViewModel.presets, id: \.self) { preset in
                        Button(preset.formatted) { viewModel.selectPreset(preset) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Section("From") {
                Picker("Payment method", selection: $viewModel.selectedMethodID) {
                    ForEach(viewModel.fundingMethods) { method in
                        Text(method.displayName).tag(Optional(method.id))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if let message = viewModel.errorMessage {
                Section {
                    Text(message).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button("Add funds") {
                    Task { await viewModel.submit() }
                }
                .buttonStyle(.primary)
                .disabled(!viewModel.canSubmit)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Add funds")
        .task { await viewModel.load() }
        .onChange(of: viewModel.newBalance) { _, balance in
            guard balance != nil else { return }
            onComplete()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AddFundsScreen(service: PreviewWalletService()) {}
    }
}
