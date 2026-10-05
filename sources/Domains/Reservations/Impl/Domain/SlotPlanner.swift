import Foundation
import ReservationsAPI

enum SlotPlanner {
    /// Every slot start on `day` between opening and the last start that still ends by closing time.
    static func slots(for schedule: VenueSchedule, on day: Date, booked: [Reservation], now: Date, calendar: Calendar = .current) -> [TimeSlot] {
        let startOfDay = calendar.startOfDay(for: day)
        guard let open = calendar.date(byAdding: .hour, value: schedule.openHour, to: startOfDay),
              let close = calendar.date(byAdding: .hour, value: schedule.closeHour, to: startOfDay) else { return [] }
        let step = TimeInterval(schedule.slotMinutes * 60)
        let duration = TimeInterval(schedule.durationMinutes * 60)
        let active = booked.filter { $0.venueID == schedule.venueID && $0.status == .confirmed }

        var slots: [TimeSlot] = []
        var start = open
        while start.addingTimeInterval(duration) <= close {
            let end = start.addingTimeInterval(duration)
            if start > now {
                let overlapping = active.count { $0.start < end && $0.end > start }
                slots.append(TimeSlot(start: start, end: end, remaining: max(0, schedule.capacity - overlapping)))
            }
            start = start.addingTimeInterval(step)
        }
        return slots
    }

    static func confirmationCode(venueName: String, seed: String) -> String {
        let prefix = venueName.uppercased().filter(\.isLetter).prefix(3)
        let suffix = seed.uppercased().filter { $0.isLetter || $0.isNumber }.suffix(3)
        return "\(prefix)-\(suffix)"
    }
}
