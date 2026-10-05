import CoreModels
import DesignSystem
import Identity
import SwiftUI

struct NotificationsScreen: View {
    let service: LiveNotificationsService
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
        .navigationTitle("Notifications")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: IdentityService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        NotificationsScreen(service: LiveNotificationsService(identity: PreviewDependency(), latency: .none))
    }
}
