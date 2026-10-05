import CoreModels
import DesignSystem
import IdentityAPI
import NotificationsAPI
import SwiftUI

struct ReservationsScreen: View {
    let service: LiveReservationsService
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
        .navigationTitle("Reservations")
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
        ReservationsScreen(service: LiveReservationsService(identity: PreviewDependency(), notifications: PreviewDependency(), latency: .none))
    }
}
