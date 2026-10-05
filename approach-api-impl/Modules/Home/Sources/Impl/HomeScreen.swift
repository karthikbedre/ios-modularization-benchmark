import CoreModels
import DesignSystem
import DiningAPI
import EventsAPI
import IdentityAPI
import LibraryAPI
import MapAPI
import NotificationsAPI
import ParkingAPI
import ReportIssueAPI
import ReservationsAPI
import SwiftUI
import TicketsAPI
import TransitAPI
import WalletAPI

struct HomeScreen: View {
    let service: LiveHomeService
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
        .navigationTitle("Home")
        .task {
            summaries = await service.allSummaries()
        }
    }
}

private struct PreviewDependency: IdentityService, MapService, NotificationsService, WalletService, TicketsService, EventsService, ParkingService, TransitService, ReservationsService, DiningService, LibraryService, ReportIssueService {
    func summary() async -> DomainSummary {
        DomainSummary(title: "Preview", detail: "Stub")
    }
}

#Preview {
    NavigationStack {
        HomeScreen(service: LiveHomeService(identity: PreviewDependency(), map: PreviewDependency(), notifications: PreviewDependency(), wallet: PreviewDependency(), tickets: PreviewDependency(), events: PreviewDependency(), parking: PreviewDependency(), transit: PreviewDependency(), reservations: PreviewDependency(), dining: PreviewDependency(), library: PreviewDependency(), reportIssue: PreviewDependency(), latency: .none))
    }
}
