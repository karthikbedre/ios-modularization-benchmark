import CoreModels
import DesignSystem
import Map
import SwiftUI
import Tickets

struct EventsScreen: View {
    let service: LiveEventsService
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
        .navigationTitle("Events")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: TicketsService, MapService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        EventsScreen(service: LiveEventsService(tickets: PreviewDependency(), map: PreviewDependency(), latency: .none))
    }
}
