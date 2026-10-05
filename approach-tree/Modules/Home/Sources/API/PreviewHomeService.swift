#if DEBUG
import CoreModels
import Foundation

public struct PreviewHomeService: HomeService {
    public init() {}

    public func dashboard() async -> Dashboard {
        Dashboard(
            greeting: "Good evening, Avery",
            unreadCount: 2,
            upNext: [UpNextItem(id: "u1", title: "Noodle Bar 88", start: .now.addingTimeInterval(7200), location: "Old Town")],
            featuredEvents: [FeaturedEvent(id: "event-jazz", title: "Autumn Jazz Night", start: .now.addingTimeInterval(3 * 86_400), venueName: "Harbor Amphitheater")],
            cards: [
                DashboardCard(section: .wallet, summary: DomainSummary(title: "Wallet", detail: "City Card balance $38.50")),
                DashboardCard(section: .parking, summary: DomainSummary(title: "Parking", detail: "Not parked")),
            ]
        )
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Home", detail: "Good evening, Avery")
    }
}
#endif
