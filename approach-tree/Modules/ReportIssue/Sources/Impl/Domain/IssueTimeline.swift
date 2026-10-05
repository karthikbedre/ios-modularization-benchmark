import Foundation

/// Stands in for the city's work queue: new reports move forward on a fixed schedule.
enum IssueTimeline {
    static let steps: [(after: TimeInterval, status: IssueStatus, note: String)] = [
        (2 * 3600, .acknowledged, "Assigned to the responsible department."),
        (2 * 86_400, .scheduled, "Crew scheduled."),
        (6 * 86_400, .resolved, "Marked resolved by the crew."),
    ]

    /// Adds any updates that are due by `now`. Reports that already have a later status are left alone.
    static func advance(_ report: IssueReport, to now: Date) -> IssueReport {
        var report = report
        for step in steps where report.status < step.status {
            let due = report.createdAt.addingTimeInterval(step.after)
            guard due <= now else { break }
            report.updates.append(IssueUpdate(date: due, status: step.status, note: step.note))
        }
        return report
    }
}
