import CoreKit
import CoreModels
import DesignSystem
import SwiftUI
import TransitAPI

struct PassesView: View {
    let service: any TransitService
    @State private var data: LoadState<(options: [PassOption], passes: [TransitPass])> = .idle
    @State private var errorMessage: String?
    @State private var buying: PassKind?

    var body: some View {
        AsyncContentView(state: data, retry: load) { data in
            List {
                let now = Date.now
                let valid = data.passes.filter { $0.isValid(at: now) }
                Section("Your passes") {
                    if valid.isEmpty {
                        Text("No valid pass").foregroundStyle(.secondary)
                    }
                    ForEach(valid) { pass in
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text(pass.kind.title).font(.headline)
                            Text("Valid until \(pass.validUntil.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(Palette.positive)
                        }
                    }
                }
                Section {
                    ForEach(data.options, id: \.kind) { option in
                        HStack {
                            Text(option.kind.title)
                            Spacer()
                            Button("Buy \(option.price.formatted)") {
                                Task { await buy(option.kind) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(buying != nil)
                        }
                    }
                } header: {
                    Text("Buy")
                } footer: {
                    Text(errorMessage ?? "Paid with your default wallet method.")
                        .foregroundStyle(errorMessage == nil ? Color.secondary : Palette.negative)
                }
                let expired = data.passes.filter { !$0.isValid(at: now) }
                if !expired.isEmpty {
                    Section("Expired") {
                        ForEach(expired) { pass in
                            KeyValueRow(pass.kind.title, value: pass.validUntil.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
            }
        }
        .task {
            if case .idle = data { await load() }
        }
    }

    private func load() async {
        do {
            async let options = service.passOptions()
            async let passes = service.passes()
            data = .loaded((try await options, try await passes))
        } catch {
            data = .failed("Passes could not be loaded.")
        }
    }

    private func buy(_ kind: PassKind) async {
        buying = kind
        defer { buying = nil }
        do {
            _ = try await service.buyPass(kind)
            errorMessage = nil
        } catch {
            errorMessage = TransitMessages.message(for: error)
        }
        await load()
    }
}
