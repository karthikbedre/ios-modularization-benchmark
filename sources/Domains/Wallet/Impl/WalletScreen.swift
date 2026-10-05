import CoreModels
import DesignSystem
import IdentityAPI
import SwiftUI

struct WalletScreen: View {
    let service: LiveWalletService
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
        .navigationTitle("Wallet")
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
        WalletScreen(service: LiveWalletService(identity: PreviewDependency(), latency: .none))
    }
}
