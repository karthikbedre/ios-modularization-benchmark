import DiningAPI
import EventsAPI
import LibraryAPI
import PlacesAPI
import SearchAPI
import SwiftUI
import TransitAPI

/// Detail screens of the domains that own each kind of result.
struct SearchUI {
    var events: EventsEntryPoints
    var dining: DiningEntryPoints
    var library: LibraryEntryPoints
    var transit: TransitEntryPoints
    var places: PlacesEntryPoints

    @MainActor
    func destination(for result: SearchResult) -> AnyView {
        switch result.scope {
        case .events: events.detail(result.itemID)
        case .restaurants: dining.detail(result.itemID)
        case .books: library.book(result.itemID)
        case .stops: transit.stop(result.itemID)
        case .places: places.place(result.itemID)
        }
    }

    @MainActor
    static var preview: SearchUI {
        let placeholder: @MainActor @Sendable (String) -> AnyView = { AnyView(Text($0)) }
        return SearchUI(
            events: EventsEntryPoints(detail: placeholder),
            dining: DiningEntryPoints(detail: placeholder),
            library: LibraryEntryPoints(book: placeholder),
            transit: TransitEntryPoints(stop: placeholder),
            places: PlacesEntryPoints(place: placeholder, location: { title, _ in AnyView(Text(title)) })
        )
    }
}

extension SearchScope {
    var systemImage: String {
        switch self {
        case .events: "calendar"
        case .restaurants: "fork.knife"
        case .books: "book"
        case .stops: "tram.fill"
        case .places: "mappin.and.ellipse"
        }
    }
}
