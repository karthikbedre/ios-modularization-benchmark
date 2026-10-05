import CoreModels
import DesignSystem
import Map
import Notifications
import SwiftUI

struct ReportIssueScreen: View {
    let service: LiveReportIssueService
    @State private var summaries: [DomainSummary] = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.medium) {
                ForEach(summaries, id: \.self) { summary in
                    SummaryCard(summary: summary)
                }
            }
            .padding(Spacing.medium)
        }
        .navigationTitle("ReportIssue")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: MapService, NotificationsService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        ReportIssueScreen(service: LiveReportIssueService(map: PreviewDependency(), notifications: PreviewDependency(), latency: .none))
    }
}
