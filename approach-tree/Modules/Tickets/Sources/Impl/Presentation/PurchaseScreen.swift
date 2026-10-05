import CoreModels
import DesignSystem
import SwiftUI
import Wallet

struct PurchaseScreen: View {
    @State private var viewModel: PurchaseViewModel
    private let wallet: WalletEntryPoints
    @Environment(\.dismiss) private var dismiss

    init(event: TicketedEvent, service: any TicketsService, wallet: WalletEntryPoints) {
        _viewModel = State(initialValue: PurchaseViewModel(event: event, service: service))
        self.wallet = wallet
    }

    var body: some View {
        Group {
            if case .confirmed(let tickets) = viewModel.phase {
                PurchaseConfirmation(tickets: tickets) { dismiss() }
            } else {
                AsyncContentView(state: viewModel.offers, retry: viewModel.load) { offers in
                    form(offers)
                }
            }
        }
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: isPaying, onDismiss: { Task { await viewModel.abandonCheckout() } }) {
            if case .paying(let hold) = viewModel.phase {
                NavigationStack {
                    VStack(spacing: 0) {
                        Label("Seats held until \(hold.expiresAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.small * 2)
                            .background(Palette.warning.opacity(0.15))
                        wallet.checkout(viewModel.paymentRequest(for: hold)) { receipt in
                            Task { await viewModel.paymentCompleted(receipt) }
                        }
                    }
                }
            }
        }
        .task {
            if case .idle = viewModel.offers { await viewModel.load() }
        }
    }

    private var isPaying: Binding<Bool> {
        Binding {
            if case .paying = viewModel.phase { true } else { false }
        } set: { _ in }
    }

    private func form(_ offers: [TicketOffer]) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(viewModel.event.title).font(.headline)
                    Text("\(viewModel.event.venueName) · \(viewModel.event.start.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Choose tickets") {
                ForEach(offers) { offer in
                    OfferRow(offer: offer, isSelected: offer.id == viewModel.selectedOfferID)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.select(offer) }
                }
            }
            if viewModel.selectedOffer != nil {
                Section {
                    Stepper("Quantity: \(viewModel.quantity)", value: $viewModel.quantity, in: 1...viewModel.maxQuantity)
                    if let total = viewModel.total {
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            AmountText(total).font(.headline)
                        }
                    }
                }
            }
            if let message = viewModel.errorMessage {
                Section {
                    Text(message).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button("Continue to payment") {
                    Task { await viewModel.startCheckout() }
                }
                .buttonStyle(.primary)
                .disabled(viewModel.selectedOffer == nil || viewModel.isWorking)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct OfferRow: View {
    let offer: TicketOffer
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(offer.isSoldOut ? Color.secondary : Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.tier.title)
                if offer.isSoldOut {
                    Text("Sold out").font(.caption).foregroundStyle(Palette.negative)
                } else if offer.remaining <= 10 {
                    Text("Only \(offer.remaining) left").font(.caption).foregroundStyle(Palette.warning)
                }
            }
            Spacer()
            AmountText(offer.price)
        }
        .opacity(offer.isSoldOut ? 0.5 : 1)
    }
}

private struct PurchaseConfirmation: View {
    let tickets: [CityTicket]
    let done: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.positive)
            Text(tickets.count == 1 ? "You're going!" : "You're going, with \(tickets.count - 1) more!")
                .font(.title2.weight(.semibold))
            if let event = tickets.first?.event {
                Text("\(event.title)\n\(event.start.formatted(date: .complete, time: .shortened))")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Text("Added to your agenda. Your tickets are in My Tickets.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Done", action: done)
                .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

#Preview {
    NavigationStack {
        PurchaseScreen(
            event: .preview,
            service: PreviewTicketsService(),
            wallet: WalletEntryPoints { _, _ in AnyView(Text("Wallet checkout")) }
        )
    }
}
