import Foundation

public enum ReminderOffset: Int, CaseIterable, Hashable, Sendable, Codable {
    case none = 0
    case fifteenMinutes = 15
    case oneHour = 60
    case oneDay = 1440

    public var title: String {
        switch self {
        case .none: "No reminder"
        case .fifteenMinutes: "15 minutes before"
        case .oneHour: "1 hour before"
        case .oneDay: "1 day before"
        }
    }

    public var interval: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

public struct CalendarDraft: Hashable, Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?
    public var sourceDomain: String
    /// Lets the source domain find its entry again, for example to show "Added".
    public var sourceItemID: String?
    public var reminder: ReminderOffset

    public init(title: String, start: Date, end: Date, location: String? = nil, sourceDomain: String, sourceItemID: String? = nil, reminder: ReminderOffset = .oneHour) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.sourceDomain = sourceDomain
        self.sourceItemID = sourceItemID
        self.reminder = reminder
    }
}

public struct CalendarEntry: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?
    public var sourceDomain: String
    public var sourceItemID: String?
    public var reminder: ReminderOffset

    public init(id: String, ownerID: String, title: String, start: Date, end: Date, location: String?, sourceDomain: String, sourceItemID: String?, reminder: ReminderOffset) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.sourceDomain = sourceDomain
        self.sourceItemID = sourceItemID
        self.reminder = reminder
    }
}

public enum AgendaError: Error, Hashable, Sendable {
    case emptyTitle
    case endsBeforeStart
    case alreadyAdded
    case notFound
}
