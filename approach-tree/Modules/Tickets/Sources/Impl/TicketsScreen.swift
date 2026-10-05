import CoreModels
import DesignSystem
import Identity
import SwiftUI
import Wallet

struct TicketsScreen: View {
    let service: LiveTicketsService
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
        .navigationTitle("Tickets")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: WalletService, IdentityService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        TicketsScreen(service: LiveTicketsService(wallet: PreviewDependency(), identity: PreviewDependency(), latency: .none))
    }
}
