import CoreModels
import DesignSystem
import Identity
import Notifications
import SwiftUI

struct LibraryScreen: View {
    let service: LiveLibraryService
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
        .navigationTitle("Library")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: IdentityService, NotificationsService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        LibraryScreen(service: LiveLibraryService(identity: PreviewDependency(), notifications: PreviewDependency(), latency: .none))
    }
}
