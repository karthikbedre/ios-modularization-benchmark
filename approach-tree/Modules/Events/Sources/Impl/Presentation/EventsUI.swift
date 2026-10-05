import Agenda
import Favorites
import Places
import SwiftUI
import Tickets

/// Cross-domain screens and controls the event screens compose.
struct EventsUI {
    var places: PlacesEntryPoints
    var favorites: FavoritesEntryPoints
    var agenda: AgendaEntryPoints
    var tickets: TicketsEntryPoints

    @MainActor
    static var preview: EventsUI {
        EventsUI(
            places: PlacesEntryPoints(place: { _ in AnyView(Text("Venue")) }, location: { _, _ in AnyView(Text("Map")) }),
            favorites: FavoritesEntryPoints(toggleButton: { _ in AnyView(Image(systemName: "heart")) }, list: { AnyView(Text("Saved")) }),
            agenda: AgendaEntryPoints(addButton: { _ in AnyView(Label("Add to agenda", systemImage: "calendar.badge.plus")) }, agenda: { AnyView(Text("Agenda")) }),
            tickets: TicketsEntryPoints(purchase: { _ in AnyView(Text("Buy tickets")) }, myTickets: { AnyView(Text("My tickets")) })
        )
    }
}

extension CityEvent {
    var ticketed: TicketedEvent {
        TicketedEvent(eventID: id, title: title, venueName: venueName, start: start, end: end)
    }

    var favoriteDraft: FavoriteDraft {
        FavoriteDraft(kind: .event, itemID: id, title: title, subtitle: venueName)
    }

    var calendarDraft: CalendarDraft {
        CalendarDraft(title: title, start: start, end: end, location: venueName, sourceDomain: "Events", sourceItemID: id, reminder: .oneHour)
    }
}

extension EventCategory {
    var systemImage: String {
        switch self {
        case .music: "music.note"
        case .film: "film"
        case .food: "fork.knife"
        case .family: "figure.2.and.child.holdinghands"
        case .sports: "figure.run"
        case .community: "person.3.fill"
        case .arts: "paintpalette.fill"
        }
    }

    var tint: Color {
        switch self {
        case .music: .purple
        case .film: .indigo
        case .food: .orange
        case .family: .pink
        case .sports: .green
        case .community: .teal
        case .arts: .red
        }
    }
}
