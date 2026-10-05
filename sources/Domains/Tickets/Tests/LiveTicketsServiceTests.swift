import CoreModels
@testable import Tickets
import TicketsAPI
import Testing

struct LiveTicketsServiceTests {
    private let repository = TicketsFixtures.repository()
    private let dependencies = TicketsFixtures.Dependencies()
    private var service: LiveTicketsService { TicketsFixtures.service(repository, dependencies) }

    @Test func offersForEventCheapestFirst() async throws {
        #expect(try await service.offers(eventID: "event-1").map(\.id) == ["ga", "res", "vip"])
    }

    @Test func holdSetsSeatsAsideForTenMinutes() async throws {
        let hold = try await service.hold(offerID: "res", quantity: 2, for: TicketsFixtures.event)

        #expect(hold.total == .usd(72))
        #expect(hold.expiresAt == dependencies.clock.now.addingTimeInterval(600))
        #expect(try await service.offers(eventID: "event-1").first { $0.id == "res" }?.remaining == 1)
    }

    @Test(arguments: [
        ("vip", 1, TicketsError.soldOut),
        ("res", 4, TicketsError.quantityOutOfRange(max: 3)),
        ("ga", 0, TicketsError.quantityOutOfRange(max: 8)),
        ("other", 1, TicketsError.offerNotFound),
    ])
    func holdRejectsInvalidRequests(offerID: String, quantity: Int, expected: TicketsError) async {
        await #expect(throws: expected) {
            try await service.hold(offerID: offerID, quantity: quantity, for: TicketsFixtures.event)
        }
    }

    @Test func expiredHoldsReturnSeatsOnNextRead() async throws {
        _ = try await service.hold(offerID: "res", quantity: 3, for: TicketsFixtures.event)
        #expect(try await service.offers(eventID: "event-1").first { $0.id == "res" }?.isSoldOut == true)

        dependencies.clock.now = dependencies.clock.now.addingTimeInterval(601)

        #expect(try await service.offers(eventID: "event-1").first { $0.id == "res" }?.remaining == 3)
    }

    @Test func confirmIssuesSeatedTicketsAndAnnounces() async throws {
        let hold = try await service.hold(offerID: "res", quantity: 2, for: TicketsFixtures.event)

        let tickets = try await service.confirm(holdID: hold.id, payment: TicketsFixtures.payment(amount: .usd(72)))

        #expect(tickets.map(\.seat) == ["Row D, seat 1", "Row D, seat 2"])
        #expect(tickets.allSatisfy { $0.price == .usd(36) && $0.transactionID == "tx-1" })
        #expect(await repository.snapshot.holds.isEmpty)
        #expect(await dependencies.agenda.added.map(\.sourceItemID) == ["event-1"])
        #expect(await dependencies.notifications.posted.map(\.title) == ["Your 2 tickets are ready"])
    }

    @Test func confirmRejectsWrongAmountAndKeepsHold() async throws {
        let hold = try await service.hold(offerID: "ga", quantity: 1, for: TicketsFixtures.event)

        await #expect(throws: TicketsError.paymentMismatch) {
            try await service.confirm(holdID: hold.id, payment: TicketsFixtures.payment(amount: .usd(1)))
        }
        #expect(await repository.snapshot.holds.count == 1)
    }

    @Test func confirmAfterExpiryReleasesSeats() async throws {
        let hold = try await service.hold(offerID: "res", quantity: 3, for: TicketsFixtures.event)
        dependencies.clock.now = hold.expiresAt

        await #expect(throws: TicketsError.holdExpired) {
            try await service.confirm(holdID: hold.id, payment: TicketsFixtures.payment(amount: hold.total))
        }
        #expect(await repository.snapshot.offers.first { $0.id == "res" }?.remaining == 3)
        #expect(await dependencies.notifications.posted.isEmpty)
    }

    @Test func releaseReturnsSeats() async throws {
        let hold = try await service.hold(offerID: "ga", quantity: 5, for: TicketsFixtures.event)

        try await service.release(holdID: hold.id)

        #expect(try await service.offers(eventID: "event-1").first?.remaining == 50)
    }

    @Test func cancelWorksUntilCutoff() async throws {
        let hold = try await service.hold(offerID: "ga", quantity: 1, for: TicketsFixtures.event)
        let ticket = try #require(try await service.confirm(holdID: hold.id, payment: TicketsFixtures.payment(amount: .usd(18))).first)

        try await service.cancel(ticketID: ticket.id)

        #expect(try await service.myTickets().first?.status == .cancelled)
        #expect(try await service.offers(eventID: "event-1").first?.remaining == 50)
    }

    @Test func cancelInsideCutoffIsRejected() async throws {
        let hold = try await service.hold(offerID: "ga", quantity: 1, for: TicketsFixtures.event)
        let ticket = try #require(try await service.confirm(holdID: hold.id, payment: TicketsFixtures.payment(amount: .usd(18))).first)
        dependencies.clock.now = TicketsFixtures.event.start.addingTimeInterval(-3600)

        await #expect(throws: TicketsError.tooLateToCancel) { try await service.cancel(ticketID: ticket.id) }
    }

    @Test func myTicketsListsUpcomingFirstThenPast() async throws {
        let past = CityTicket(id: "old", ownerID: "user-1", event: TicketedEvent(eventID: "e0", title: "Old", venueName: "V", start: TicketsFixtures.start.addingTimeInterval(-86_400), end: TicketsFixtures.start.addingTimeInterval(-80_000)),
                              tier: .general, seat: nil, price: .usd(5), status: .used, purchasedAt: TicketsFixtures.start, transactionID: "t")
        let upcoming = CityTicket(id: "new", ownerID: "user-1", event: TicketsFixtures.event, tier: .general, seat: nil, price: .usd(18), status: .active, purchasedAt: TicketsFixtures.start, transactionID: "t")
        let someoneElses = CityTicket(id: "x", ownerID: "user-2", event: TicketsFixtures.event, tier: .general, seat: nil, price: .usd(18), status: .active, purchasedAt: TicketsFixtures.start, transactionID: "t")
        let service = TicketsFixtures.service(TicketsFixtures.repository(tickets: [past, someoneElses, upcoming]))

        #expect(try await service.myTickets().map(\.id) == ["new", "old"])
    }
}

struct SeatAssignerTests {
    @Test(arguments: [
        (TicketTier.general, 0, nil),
        (TicketTier.vip, 0, "Row A, seat 1"),
        (TicketTier.vip, 21, "Row B, seat 2"),
        (TicketTier.reserved, 19, "Row D, seat 20"),
    ])
    func assignsRowsOfTwenty(tier: TicketTier, number: Int, expected: String?) {
        #expect(SeatAssigner.seat(for: tier, number: number) == expected)
    }
}

@MainActor
struct PurchaseViewModelTests {
    @Test func preselectsFirstAvailableOfferAndClampsQuantity() async {
        let viewModel = PurchaseViewModel(event: TicketsFixtures.event, service: TicketsFixtures.service(TicketsFixtures.repository()))
        await viewModel.load()
        #expect(viewModel.selectedOfferID == "ga")

        viewModel.quantity = 5
        viewModel.select(viewModel.offers.value![1])

        #expect(viewModel.quantity == 3)
        #expect(viewModel.total == .usd(108))
    }

    @Test func soldOutOfferCannotBeSelected() async {
        let viewModel = PurchaseViewModel(event: TicketsFixtures.event, service: TicketsFixtures.service(TicketsFixtures.repository()))
        await viewModel.load()

        viewModel.select(viewModel.offers.value![2])

        #expect(viewModel.selectedOfferID == "ga")
    }

    @Test func checkoutThenPaymentConfirmsTickets() async throws {
        let viewModel = PurchaseViewModel(event: TicketsFixtures.event, service: TicketsFixtures.service(TicketsFixtures.repository()))
        await viewModel.load()
        viewModel.quantity = 2

        await viewModel.startCheckout()
        guard case .paying(let hold) = viewModel.phase else { Issue.record("expected paying"); return }
        #expect(viewModel.paymentRequest(for: hold).amount == .usd(36))
        await viewModel.paymentCompleted(TicketsFixtures.receipt(amount: hold.total))

        guard case .confirmed(let tickets) = viewModel.phase else { Issue.record("expected confirmed"); return }
        #expect(tickets.count == 2)
    }

    @Test func abandoningCheckoutReleasesSeats() async {
        let repository = TicketsFixtures.repository()
        let viewModel = PurchaseViewModel(event: TicketsFixtures.event, service: TicketsFixtures.service(repository))
        await viewModel.load()
        viewModel.quantity = 4

        await viewModel.startCheckout()
        await viewModel.abandonCheckout()

        #expect(viewModel.phase == .choosing)
        #expect(await repository.snapshot.offers.first?.remaining == 50)
    }
}
