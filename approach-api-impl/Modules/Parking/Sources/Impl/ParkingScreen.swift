import CoreModels
import DesignSystem
import MapAPI
import SwiftUI
import WalletAPI

struct ParkingScreen: View {
    let service: LiveParkingService
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
        .navigationTitle("Parking")
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
        ParkingScreen(service: LiveParkingService(wallet: PreviewDependency(), map: PreviewDependency(), latency: .none))
    }
}
