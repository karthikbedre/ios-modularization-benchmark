import CoreModels
import DesignSystem
import Map
import Reservations
import SwiftUI

struct DiningScreen: View {
    let service: LiveDiningService
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
        .navigationTitle("Dining")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: ReservationsService, MapService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        DiningScreen(service: LiveDiningService(reservations: PreviewDependency(), map: PreviewDependency(), latency: .none))
    }
}
