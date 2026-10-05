import Foundation

struct EventSection: Identifiable, Hashable, Sendable {
    enum Period: Int, Comparable, Hashable, Sendable {
        case today, thisWeekend, thisWeek, later

        var title: String {
            switch self {
            case .today: "Today"
            case .thisWeekend: "This weekend"
            case .thisWeek: "This week"
            case .later: "Coming up"
            }
        }

        static func < (lhs: Period, rhs: Period) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var period: Period
    var events: [CityEvent]

    var id: Period { period }

    /// Buckets relative to `now`. Weekend means Saturday and Sunday of the current week.
    static func make(_ events: [CityEvent], now: Date, calendar: Calendar = .current) -> [EventSection] {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekday = calendar.component(.weekday, from: today)
        let daysToSaturday = (7 - weekday) % 7
        let saturday = calendar.date(byAdding: .day, value: daysToSaturday, to: today)!
        let monday = calendar.date(byAdding: .day, value: 2, to: saturday)!

        func period(for event: CityEvent) -> Period {
            if event.start < tomorrow { return .today }
            if event.start >= saturday && event.start < monday { return .thisWeekend }
            if event.start < saturday { return .thisWeek }
            return .later
        }

        return Dictionary(grouping: events, by: period)
            .map { EventSection(period: $0.key, events: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.period < $1.period }
    }
}
