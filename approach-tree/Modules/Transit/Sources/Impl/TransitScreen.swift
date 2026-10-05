import CoreModels
import DesignSystem
import Map
import SwiftUI
import Wallet

struct TransitScreen: View {
    let service: LiveTransitService
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
        .navigationTitle("Transit")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: WalletService, MapService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        TransitScreen(service: LiveTransitService(wallet: PreviewDependency(), map: PreviewDependency(), latency: .none))
    }
}
