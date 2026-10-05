import DesignSystem
import SwiftUI

extension IssueCategory {
    var systemImage: String {
        switch self {
        case .pothole: "road.lanes"
        case .streetlight: "lightbulb.slash"
        case .graffiti: "paintbrush.pointed"
        case .litter: "trash"
        case .sidewalk: "figure.walk"
        case .noise: "speaker.wave.3"
        case .other: "questionmark.bubble"
        }
    }
}

extension IssueStatus {
    var tint: Color {
        switch self {
        case .submitted: .secondary
        case .acknowledged: Palette.accent
        case .scheduled: Palette.warning
        case .resolved: Palette.positive
        }
    }
}

enum ReportIssueMessages {
    static func message(for error: any Error) -> String {
        switch error as? ReportIssueError {
        case .detailsTooShort(let minimum): "Describe the issue in at least \(minimum) characters."
        case .possibleDuplicate: "Someone already reported this nearby."
        case .reportNotFound: "This report could not be found."
        case .cannotSupportOwnReport: "This is your own report."
        case nil: "The report could not be sent. Try again."
        }
    }
}
