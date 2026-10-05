import Foundation

enum InboxFilter: Hashable, Sendable {
    case all
    case unread
    case category(NotificationCategory)

    func includes(_ notification: CityNotification) -> Bool {
        switch self {
        case .all: true
        case .unread: !notification.isRead
        case .category(let category): notification.category == category
        }
    }
}

struct InboxSection: Identifiable, Hashable, Sendable {
    enum Period: Int, Hashable, Sendable, Comparable {
        case today, thisWeek, earlier

        var title: String {
            switch self {
            case .today: "Today"
            case .thisWeek: "This week"
            case .earlier: "Earlier"
            }
        }

        static func < (lhs: Period, rhs: Period) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var period: Period
    var notifications: [CityNotification]

    var id: Period { period }

    /// Buckets relative to `now`. Input order is kept within a bucket.
    static func make(_ notifications: [CityNotification], filter: InboxFilter, now: Date, calendar: Calendar = .current) -> [InboxSection] {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let grouped = Dictionary(grouping: notifications.filter(filter.includes)) { notification -> Period in
            if notification.date >= startOfToday { return .today }
            if notification.date >= startOfWeek { return .thisWeek }
            return .earlier
        }
        return grouped
            .map { InboxSection(period: $0.key, notifications: $0.value) }
            .sorted { $0.period < $1.period }
    }
}
