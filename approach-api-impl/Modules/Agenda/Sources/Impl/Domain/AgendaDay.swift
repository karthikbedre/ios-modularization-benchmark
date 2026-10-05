import AgendaAPI
import Foundation

struct AgendaDay: Identifiable, Hashable, Sendable {
    var day: Date
    var entries: [CalendarEntry]

    var id: Date { day }

    /// One day per calendar day in `days`, including empty days, so the agenda reads as a week.
    static func week(starting start: Date, days: Int = 7, entries: [CalendarEntry], calendar: Calendar = .current) -> [AgendaDay] {
        let first = calendar.startOfDay(for: start)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let matching = entries.filter { $0.start < next && $0.end > day }.sorted { $0.start < $1.start }
            return AgendaDay(day: day, entries: matching)
        }
    }
}
