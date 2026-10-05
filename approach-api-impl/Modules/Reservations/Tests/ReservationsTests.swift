import Foundation
@testable import Reservations
import ReservationsAPI
import Testing

private typealias F = ReservationsFixtures

struct SlotPlannerTests {
    @Test func slotsRunFromOpeningToLastStartThatEndsByClosing() {
        let slots = SlotPlanner.slots(for: F.bistro, on: F.at(hour: 0, daysFromNow: 1), booked: [], now: F.now, calendar: F.utc)

        #expect(slots.map(\.start) == [17, 18, 19, 20].map { F.at(hour: $0, daysFromNow: 1) })
        #expect(slots.allSatisfy { $0.remaining == 2 })
    }

    @Test func pastSlotsAreDropped() {
        let slots = SlotPlanner.slots(for: F.court, on: F.now, booked: [], now: F.at(hour: 10, minute: 30), calendar: F.utc)

        #expect(slots.map(\.start) == [F.at(hour: 11)])
    }

    @Test func confirmedOverlapsReduceCapacityButCancelledDoNot() {
        let start = F.at(hour: 18, daysFromNow: 1)
        let booked = [
            F.reservation("a", venue: F.bistro, start: start),
            F.reservation("b", venue: F.bistro, start: start, status: .cancelled),
            F.reservation("c", venue: F.court, start: start),
        ]

        let slots = SlotPlanner.slots(for: F.bistro, on: start, booked: booked, now: F.now, calendar: F.utc)

        #expect(slots.first { $0.start == start }?.remaining == 1)
    }

    @Test func confirmationCodeUsesVenueAndSeed() {
        #expect(SlotPlanner.confirmationCode(venueName: "Noodle Bar 88", seed: "res-4kq9z") == "NOO-Q9Z")
    }
}

struct LiveReservationsServiceTests {
    @Test func bookTrimsNotesAddsAgendaEntryAndConfirms() async throws {
        let notifications = RecordingNotificationsService()
        let agenda = RecordingAgendaService()
        let repository = F.repository()
        let service = F.service(repository, notifications: notifications, agenda: agenda)

        let reservation = try await service.book(F.request(F.bistro, start: F.at(hour: 19, daysFromNow: 1)))

        #expect(reservation.notes == "Birthday")
        #expect(reservation.end == F.at(hour: 20, daysFromNow: 1))
        #expect(reservation.confirmationCode == "BIS-123")
        #expect(await agenda.added.map(\.sourceItemID) == ["res-abc123"])
        #expect(await notifications.posted.map(\.title) == ["Table confirmed"])
        #expect(try await service.upcoming().map(\.id) == ["res-abc123"])
    }

    @Test func fullSlotCannotBeBooked() async {
        let start = F.at(hour: 10, daysFromNow: 1)
        let service = F.service(F.repository([F.reservation("taken", venue: F.court, start: start, owner: "user-2")]))

        await #expect(throws: ReservationsError.slotUnavailable) {
            try await service.book(F.request(F.court, start: start))
        }
    }

    @Test(arguments: [
        (7, ReservationsError.partySizeOutOfRange(max: 6)),
        (0, ReservationsError.partySizeOutOfRange(max: 6)),
    ])
    func partySizeIsBounded(partySize: Int, expected: ReservationsError) async {
        let service = F.service(F.repository())

        await #expect(throws: expected) {
            try await service.book(F.request(F.bistro, start: F.at(hour: 19, daysFromNow: 1), partySize: partySize))
        }
    }

    @Test func offGridAndPastTimesAreRejected() async {
        let service = F.service(F.repository())

        await #expect(throws: ReservationsError.slotUnavailable) {
            try await service.book(F.request(F.bistro, start: F.at(hour: 19, minute: 15, daysFromNow: 1)))
        }
        await #expect(throws: ReservationsError.slotInPast) {
            try await service.book(F.request(F.court, start: F.at(hour: 9)))
        }
    }

    @Test func overlappingOwnBookingIsRejected() async {
        let start = F.at(hour: 18, daysFromNow: 1)
        let service = F.service(F.repository([F.reservation("mine", venue: F.court, start: start.addingTimeInterval(-1800))]))

        await #expect(throws: ReservationsError.alreadyBooked) {
            try await service.book(F.request(F.bistro, start: start))
        }
    }

    @Test func cancelMovesToHistoryAndNotifies() async throws {
        let notifications = RecordingNotificationsService()
        let repository = F.repository([F.reservation("mine", venue: F.bistro, start: F.at(hour: 18, daysFromNow: 1))])
        let service = F.service(repository, notifications: notifications)

        try await service.cancel(id: "mine")

        #expect(try await service.upcoming().isEmpty)
        #expect(try await service.history().map(\.status) == [.cancelled])
        #expect(await notifications.posted.map(\.title) == ["Reservation cancelled"])
    }

    @Test func startedOrForeignReservationsCannotBeCancelled() async {
        let service = F.service(F.repository([
            F.reservation("started", venue: F.court, start: F.at(hour: 11, daysFromNow: -1)),
            F.reservation("foreign", venue: F.court, start: F.at(hour: 10, daysFromNow: 2), owner: "user-2"),
        ]))

        await #expect(throws: ReservationsError.alreadyStarted) { try await service.cancel(id: "started") }
        await #expect(throws: ReservationsError.reservationNotFound) { try await service.cancel(id: "foreign") }
    }
}

@MainActor
struct BookingViewModelTests {
    private func viewModel(_ repository: InMemoryReservationsRepository = F.repository()) -> BookingViewModel {
        BookingViewModel(venue: BookableVenue(id: "bistro", name: "Bistro", kind: .dining), service: F.service(repository), dates: .fixed(F.now), calendar: F.utc)
    }

    @Test func offersSevenDaysAndClampsPartySizeToVenue() async {
        let viewModel = viewModel()
        viewModel.partySize = 9

        await viewModel.loadSlots()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.partySize == 6)
        #expect(viewModel.slots.value?.count == 4)
    }

    @Test func bookingSelectedSlotConfirms() async {
        let viewModel = viewModel()
        await viewModel.loadSlots()
        viewModel.selectedSlot = viewModel.slots.value?.first

        await viewModel.book()

        #expect(viewModel.confirmed?.start == F.at(hour: 17))
        #expect(viewModel.errorMessage == nil)
    }

    @Test func takenSlotShowsMessageAndClearsSelection() async {
        let repository = F.repository()
        let viewModel = viewModel(repository)
        await viewModel.loadSlots()
        let slot = viewModel.slots.value![0]
        viewModel.selectedSlot = slot
        _ = try? await repository.update { snapshot in
            snapshot.reservations += [F.reservation("x", venue: F.bistro, start: slot.start, owner: "user-2"),
                                      F.reservation("y", venue: F.bistro, start: slot.start, owner: "user-3")]
        }

        await viewModel.book()

        #expect(viewModel.errorMessage == "That time was just taken. Pick another.")
        #expect(viewModel.selectedSlot == nil)
    }
}
