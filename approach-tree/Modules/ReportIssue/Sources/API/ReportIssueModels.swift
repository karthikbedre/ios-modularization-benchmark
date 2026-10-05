import CoreModels
import Foundation

public enum IssueCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case pothole, streetlight, graffiti, litter, sidewalk, noise, other

    public var title: String {
        switch self {
        case .pothole: "Pothole"
        case .streetlight: "Streetlight out"
        case .graffiti: "Graffiti"
        case .litter: "Litter or dumping"
        case .sidewalk: "Damaged sidewalk"
        case .noise: "Noise"
        case .other: "Something else"
        }
    }
}

public enum IssueStatus: String, CaseIterable, Comparable, Hashable, Sendable, Codable {
    case submitted, acknowledged, scheduled, resolved

    public var title: String { rawValue.capitalized }

    public static func < (lhs: IssueStatus, rhs: IssueStatus) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public struct IssueUpdate: Hashable, Sendable, Codable {
    public var date: Date
    public var status: IssueStatus
    public var note: String

    public init(date: Date, status: IssueStatus, note: String) {
        self.date = date
        self.status = status
        self.note = note
    }
}

public struct IssueReport: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var reporterID: String
    public var category: IssueCategory
    public var details: String
    public var location: GeoPoint
    public var addressHint: String
    public var createdAt: Date
    public var updates: [IssueUpdate]
    public var supporterIDs: Set<String>

    public init(id: String, reporterID: String, category: IssueCategory, details: String, location: GeoPoint, addressHint: String, createdAt: Date, updates: [IssueUpdate], supporterIDs: Set<String> = []) {
        self.id = id
        self.reporterID = reporterID
        self.category = category
        self.details = details
        self.location = location
        self.addressHint = addressHint
        self.createdAt = createdAt
        self.updates = updates
        self.supporterIDs = supporterIDs
    }

    public var status: IssueStatus { updates.map(\.status).max() ?? .submitted }
    public var isOpen: Bool { status != .resolved }
}

public struct IssueDraft: Hashable, Sendable {
    public var category: IssueCategory
    public var details: String
    public var location: GeoPoint
    public var addressHint: String
    /// Set after the resident has seen a possible duplicate and wants to file anyway.
    public var confirmedNotDuplicate: Bool

    public init(category: IssueCategory, details: String, location: GeoPoint, addressHint: String, confirmedNotDuplicate: Bool = false) {
        self.category = category
        self.details = details
        self.location = location
        self.addressHint = addressHint
        self.confirmedNotDuplicate = confirmedNotDuplicate
    }
}

public enum ReportIssueError: Error, Hashable, Sendable {
    case detailsTooShort(minimum: Int)
    case possibleDuplicate(reportID: String)
    case reportNotFound
    case cannotSupportOwnReport
}
