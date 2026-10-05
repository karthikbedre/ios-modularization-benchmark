import CoreKit
import CoreModels
import Foundation
import Observation
import TicketsAPI
import WalletAPI

@MainActor
@Observable
final class PurchaseViewModel {
    enum Phase: Equatable {
        case choosing
        case paying(TicketHold)
        case confirmed([CityTicket])
    }

    let event: TicketedEvent
    private(set) var offers: LoadState<[TicketOffer]> = .idle
    private(set) var phase: Phase = .choosing
    private(set) var errorMessage: String?
    private(set) var isWorking = false
    var selectedOfferID: String?
    var quantity = 1

    private let service: any TicketsService

    init(event: TicketedEvent, service: any TicketsService) {
        self.event = event
        self.service = service
    }

    var selectedOffer: TicketOffer? {
        offers.value?.first { $0.id == selectedOfferID }
    }

    var maxQuantity: Int {
        selectedOffer.map { max(1, min($0.maxPerOrder, $0.remaining)) } ?? 1
    }

    var total: Money? {
        selectedOffer.map { $0.price * quantity }
    }

    func load() async {
        offers = .loading
        do {
            let loaded = try await service.offers(eventID: event.eventID)
            offers = .loaded(loaded)
            if selectedOffer?.isSoldOut ?? true {
                selectedOfferID = loaded.first { !$0.isSoldOut }?.id
            }
            quantity = min(quantity, maxQuantity)
        } catch {
            offers = .failed("Tickets could not be loaded.")
        }
    }

    func select(_ offer: TicketOffer) {
        guard !offer.isSoldOut else { return }
        selectedOfferID = offer.id
        quantity = min(quantity, maxQuantity)
    }

    func startCheckout() async {
        guard let selectedOfferID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            phase = .paying(try await service.hold(offerID: selectedOfferID, quantity: quantity, for: event))
            errorMessage = nil
        } catch let error as TicketsError {
            errorMessage = error.message
            await load()
        } catch {
            errorMessage = "Those tickets could not be held."
        }
    }

    func paymentRequest(for hold: TicketHold) -> PaymentRequest {
        PaymentRequest(merchant: hold.event.venueName, category: .tickets, amount: hold.total, reference: "\(hold.quantity) × \(hold.event.title)")
    }

    func paymentCompleted(_ receipt: PaymentReceipt) async {
        guard case .paying(let hold) = phase else { return }
        do {
            let payment = TicketPayment(transactionID: receipt.transactionID, amount: receipt.amount)
            phase = .confirmed(try await service.confirm(holdID: hold.id, payment: payment))
            errorMessage = nil
        } catch let error as TicketsError {
            errorMessage = error.message
            phase = .choosing
            await load()
        } catch {
            errorMessage = "Your payment went through but the tickets could not be issued. Contact the box office."
        }
    }

    /// Called when checkout is dismissed without paying.
    func abandonCheckout() async {
        guard case .paying(let hold) = phase else { return }
        try? await service.release(holdID: hold.id)
        phase = .choosing
        await load()
    }
}

extension TicketsError {
    var message: String {
        switch self {
        case .offerNotFound: "These tickets are no longer on sale."
        case .soldOut: "Sold out. Try another tier."
        case .quantityOutOfRange(let max): "You can buy up to \(max) of these."
        case .holdExpired: "Your hold expired. Pick your tickets again."
        case .holdNotFound: "Your hold could not be found. Pick your tickets again."
        case .paymentMismatch: "The payment did not match the order total."
        case .ticketNotFound: "This ticket could not be found."
        case .tooLateToCancel: "Tickets can only be cancelled up to 24 hours before the event."
        }
    }
}
