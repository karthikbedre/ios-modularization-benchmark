import CoreModels
import DesignSystem
import SwiftUI

struct IdentityScreen: View {
    let service: LiveIdentityService
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
        .navigationTitle("Identity")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

#Preview {
    NavigationStack {
        IdentityScreen(service: LiveIdentityService(latency: .none))
    }
}
