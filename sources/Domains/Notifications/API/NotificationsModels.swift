import Foundation

public enum NotificationCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case payment, booking, reminder, cityAlert, library, report

    public var title: String {
        switch self {
        case .payment: "Payments"
        case .booking: "Bookings"
        case .reminder: "Reminders"
        case .cityAlert: "City alerts"
        case .library: "Library"
        case .report: "Reports"
        }
    }
}

public struct CityNotification: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var recipientID: String
    public var title: String
    public var body: String
    /// When the notification is delivered. Future dates are scheduled and not yet in the inbox.
    public var date: Date
    public var category: NotificationCategory
    public var sourceDomain: String
    public var isRead: Bool

    public init(id: String, recipientID: String, title: String, body: String, date: Date, category: NotificationCategory, sourceDomain: String, isRead: Bool) {
        self.id = id
        self.recipientID = recipientID
        self.title = title
        self.body = body
        self.date = date
        self.category = category
        self.sourceDomain = sourceDomain
        self.isRead = isRead
    }
}

public struct NotificationDraft: Hashable, Sendable {
    public var title: String
    public var body: String
    public var category: NotificationCategory
    public var sourceDomain: String
    /// Delivers later instead of now, for reminders.
    public var deliverAt: Date?

    public init(title: String, body: String, category: NotificationCategory, sourceDomain: String, deliverAt: Date? = nil) {
        self.title = title
        self.body = body
        self.category = category
        self.sourceDomain = sourceDomain
        self.deliverAt = deliverAt
    }
}

public struct NotificationPreferences: Hashable, Sendable, Codable {
    /// Muted categories still reach the inbox, but arrive already read.
    public var mutedCategories: Set<NotificationCategory>

    public init(mutedCategories: Set<NotificationCategory> = []) {
        self.mutedCategories = mutedCategories
    }
}

public enum NotificationsError: Error, Hashable, Sendable {
    case emptyTitle
    case notFound
}
