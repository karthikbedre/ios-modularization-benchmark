import CoreKit
import Foundation
import Observation

@MainActor
@Observable
final class BookingViewModel {
    let venue: BookableVenue
    let days: [Date]
    var selectedDay: Date
    var partySize = 2
    var notes = ""
    var selectedSlot: TimeSlot?
    private(set) var maxPartySize = 8
    private(set) var slots: LoadState<[TimeSlot]> = .idle
    private(set) var confirmed: Reservation?
    private(set) var errorMessage: String?
    private(set) var isBooking = false

    private let service: any ReservationsService

    init(venue: BookableVenue, service: any ReservationsService, dates: DateProvider = .live, calendar: Calendar = .current) {
        self.venue = venue
        self.service = service
        let today = calendar.startOfDay(for: dates.now)
        days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        selectedDay = today
    }

    /// Reloads slots for the selected day and party size. Clears a selection that is no longer offered.
    func loadSlots() async {
        slots = .loading
        do {
            maxPartySize = try await service.maxPartySize(venueID: venue.id)
            partySize = min(partySize, maxPartySize)
            let loaded = try await service.availableSlots(venueID: venue.id, on: selectedDay, partySize: partySize)
            slots = .loaded(loaded)
            if let selectedSlot, !loaded.contains(where: { $0.start == selectedSlot.start && !$0.isFull }) {
                self.selectedSlot = nil
            }
        } catch {
            slots = .failed("Availability could not be loaded.")
        }
    }

    func book() async {
        guard let selectedSlot else { return }
        isBooking = true
        defer { isBooking = false }
        do {
            confirmed = try await service.book(ReservationRequest(venue: venue, start: selectedSlot.start, partySize: partySize, notes: notes))
            errorMessage = nil
        } catch let error as ReservationsError {
            errorMessage = error.message
            await loadSlots()
        } catch {
            errorMessage = "The booking did not go through."
        }
    }
}

extension ReservationsError {
    var message: String {
        switch self {
        case .venueNotFound: "This venue is not taking bookings."
        case .partySizeOutOfRange(let max): "Parties of up to \(max) can book online."
        case .slotUnavailable: "That time was just taken. Pick another."
        case .slotInPast: "That time has already passed."
        case .alreadyBooked: "You already have a booking at that time."
        case .reservationNotFound: "This reservation could not be found."
        case .alreadyStarted: "This reservation has already started."
        }
    }
}
