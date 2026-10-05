import CoreModels
import DesignSystem
import SwiftUI

struct MapScreen: View {
    let service: LiveMapService
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
        .navigationTitle("Map")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

#Preview {
    NavigationStack {
        MapScreen(service: LiveMapService(latency: .none))
    }
}
