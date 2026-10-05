import CoreImage.CIFilterBuiltins
import DesignSystem
import SwiftUI

struct TicketDetailScreen: View {
    let ticket: CityTicket
    let service: any TicketsService
    let onChange: () -> Void
    @State private var confirmsCancel = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.medium) {
                    if let code = QRCode.image(for: ticket.id), ticket.status == .active {
                        Image(uiImage: code)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .accessibilityLabel("Ticket code")
                    }
                    Text(ticket.event.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.medium)
            }
            Section {
                KeyValueRow("When", value: ticket.event.start.formatted(date: .complete, time: .shortened))
                KeyValueRow("Where", value: ticket.event.venueName)
                KeyValueRow("Tier", value: ticket.tier.title)
                if let seat = ticket.seat {
                    KeyValueRow("Seat", value: seat)
                }
                KeyValueRow("Paid", value: ticket.price.formatted)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
            }
            if ticket.status == .active {
                Section {
                    Button("Cancel ticket", role: .destructive) { confirmsCancel = true }
                }
            }
        }
        .navigationTitle("Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Cancel this ticket?", isPresented: $confirmsCancel, titleVisibility: .visible) {
            Button("Cancel ticket", role: .destructive) {
                Task { await cancel() }
            }
        } message: {
            Text("Your seat is released for someone else.")
        }
    }

    private func cancel() async {
        do {
            try await service.cancel(ticketID: ticket.id)
            onChange()
            dismiss()
        } catch let error as TicketsError {
            errorMessage = error.message
        } catch {
            errorMessage = "The ticket could not be cancelled."
        }
    }
}

enum QRCode {
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        TicketDetailScreen(
            ticket: CityTicket(id: "t1", ownerID: "u", event: .preview, tier: .reserved, seat: "Row D, seat 4", price: .usd(36), status: .active, purchasedAt: .now, transactionID: "tx"),
            service: PreviewTicketsService()
        ) {}
    }
}
