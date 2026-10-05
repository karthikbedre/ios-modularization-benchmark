import CoreKit
import DesignSystem
import SwiftUI
import TicketsAPI

struct MyTicketsScreen: View {
    let service: any TicketsService
    @State private var tickets: LoadState<[CityTicket]> = .idle

    var body: some View {
        AsyncContentView(state: tickets, retry: load) { tickets in
            if tickets.isEmpty {
                EmptyStateView("No tickets yet", systemImage: "ticket", message: "Tickets you buy for city events show up here.")
            } else {
                let upcoming = tickets.filter { $0.status == .active && $0.event.end > .now }
                let past = tickets.filter { !upcoming.contains($0) }
                List {
                    if !upcoming.isEmpty {
                        Section("Upcoming") {
                            ForEach(upcoming) { ticket in
                                NavigationLink(value: ticket) { TicketRow(ticket: ticket) }
                            }
                        }
                    }
                    if !past.isEmpty {
                        Section("Past and cancelled") {
                            ForEach(past) { ticket in
                                NavigationLink(value: ticket) { TicketRow(ticket: ticket) }
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("My Tickets")
        .navigationDestination(for: CityTicket.self) { ticket in
            TicketDetailScreen(ticket: ticket, service: service) {
                Task { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            tickets = .loaded(try await service.myTickets())
        } catch {
            tickets = .failed("Your tickets could not be loaded.")
        }
    }
}

struct TicketRow: View {
    let ticket: CityTicket

    var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(spacing: 0) {
                Text(ticket.event.start, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                Text(ticket.event.start, format: .dateTime.day())
                    .font(.title3.weight(.bold))
            }
            .frame(width: 44)
            .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.event.title)
                Text([ticket.tier.title, ticket.seat].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            switch ticket.status {
            case .active: EmptyView()
            case .used: StatusBadge("Used", color: .secondary)
            case .cancelled: StatusBadge("Cancelled", color: Palette.negative)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyTicketsScreen(service: PreviewTicketsService())
    }
}
