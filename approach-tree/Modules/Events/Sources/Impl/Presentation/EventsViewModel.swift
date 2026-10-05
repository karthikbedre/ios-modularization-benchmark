import CoreKit
import Foundation
import Observation

@MainActor
@Observable
final class EventsViewModel {
    struct Content: Equatable {
        var featured: [CityEvent]
        var sections: [EventSection]
    }

    private(set) var state: LoadState<Content> = .idle
    var category: EventCategory?
    var searchText = ""
    private(set) var searchResults: [CityEvent] = []

    let service: any EventsService
    private let dates: DateProvider
    private let calendar: Calendar

    init(service: any EventsService, dates: DateProvider = .live, calendar: Calendar = .current) {
        self.service = service
        self.dates = dates
        self.calendar = calendar
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let featured = service.featured()
            async let upcoming = service.upcoming(category: category)
            state = .loaded(Content(
                featured: category == nil ? try await featured : [],
                sections: EventSection.make(try await upcoming, now: dates.now, calendar: calendar)
            ))
        } catch {
            state = .failed("Events could not be loaded.")
        }
    }

    func runSearch() async {
        searchResults = isSearching ? ((try? await service.search(searchText)) ?? []) : []
    }
}
