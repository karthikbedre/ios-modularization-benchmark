import CoreKit
import DesignSystem
import EventsAPI
import SwiftUI

struct EventDetailScreen: View {
    let event: CityEvent
    let ui: EventsUI
    @State private var buysTickets = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.small * 2) {
                    Label(event.category.title, systemImage: event.category.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(event.category.tint)
                    Text(event.title)
                        .font(.title2.weight(.bold))
                    Text(event.summary)
                        .foregroundStyle(.secondary)
                    if !event.tags.isEmpty {
                        HStack {
                            ForEach(event.tags, id: \.self) { tag in
                                StatusBadge(tag, color: .secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.small)
            }
            Section {
                KeyValueRow("When", value: event.start.formatted(date: .complete, time: .shortened))
                KeyValueRow("Ends", value: event.end.formatted(date: .omitted, time: .shortened))
                NavigationLink {
                    ui.places.place(event.venuePlaceID)
                } label: {
                    KeyValueRow("Where", value: event.venueName)
                }
                KeyValueRow("Organizer", value: event.organizer)
                KeyValueRow("Price", value: event.priceFrom.map { "from \($0.formatted)" } ?? "Free")
            }
            Section {
                ui.agenda.addButton(event.calendarDraft)
                if !event.isFree && event.end > .now {
                    Button("Buy tickets", systemImage: "ticket") { buysTickets = true }
                }
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ui.favorites.toggleButton(event.favoriteDraft)
        }
        .sheet(isPresented: $buysTickets) {
            NavigationStack {
                ui.tickets.purchase(event.ticketed)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { buysTickets = false }
                        }
                    }
            }
        }
    }
}

/// Resolves an event by ID for other domains, such as Search.
struct EventLookupScreen: View {
    let eventID: String
    let service: any EventsService
    let ui: EventsUI
    @State private var event: LoadState<CityEvent> = .idle

    var body: some View {
        AsyncContentView(state: event, retry: load) { event in
            EventDetailScreen(event: event, ui: ui)
        }
        .task {
            if case .idle = event { await load() }
        }
    }

    private func load() async {
        do {
            event = .loaded(try await service.event(id: eventID))
        } catch {
            event = .failed("This event could not be found.")
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailScreen(event: .preview, ui: .preview)
    }
}
