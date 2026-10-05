import CoreModels
@testable import Events
import Events
import Foundation
import Testing

private let now = Date(timeIntervalSince1970: 1_791_201_600) // Monday 2026-10-05 12:00 UTC.

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func event(_ id: String, inHours hours: Double, category: EventCategory = .music, featured: Bool = false, tags: [String] = [], price: Money? = .usd(10)) -> CityEvent {
    CityEvent(id: id, title: "Title \(id)", summary: "Summary", category: category, start: now.addingTimeInterval(hours * 3600),
              end: now.addingTimeInterval(hours * 3600 + 7200), venuePlaceID: "p", venueName: "Harbor Amphitheater",
              organizer: "Org", priceFrom: price, isFeatured: featured, tags: tags)
}

private let events = [
    event("ended", inHours: -5),
    event("today", inHours: 3, featured: true),
    event("thursday", inHours: 72, category: .film, tags: ["outdoor"]),
    event("saturday", inHours: 120, category: .food, featured: true, price: nil),
    event("next-week", inHours: 200, category: .film),
]

struct LiveEventsServiceTests {
    private let service = LiveEventsService(repository: InMemoryEventsRepository(stored: events), dates: .fixed(now))

    @Test func upcomingExcludesEndedEventsSoonestFirst() async throws {
        #expect(try await service.upcoming(category: nil).map(\.id) == ["today", "thursday", "saturday", "next-week"])
        #expect(try await service.upcoming(category: .film).map(\.id) == ["thursday", "next-week"])
    }

    @Test func featuredIsUpcomingAndFlagged() async throws {
        #expect(try await service.featured().map(\.id) == ["today", "saturday"])
    }

    @Test func searchMatchesEveryTermAcrossFields() async throws {
        #expect(try await service.search("outdoor").map(\.id) == ["thursday"])
        #expect(try await service.search("harbor food").map(\.id) == ["saturday"])
        #expect(try await service.search("   ").isEmpty)
        #expect(try await service.search("ended").isEmpty)
    }

    @Test func unknownEventThrows() async {
        await #expect(throws: EventsError.notFound) { try await service.event(id: "missing") }
    }

    @Test func summaryCountsThisWeek() async {
        #expect(await service.summary().detail == "3 this week · next Title today")
    }
}

struct EventSectionTests {
    @Test func bucketsTodayWeekendWeekAndLater() {
        let upcoming = Array(events.dropFirst())

        let sections = EventSection.make(upcoming, now: now, calendar: utc)

        #expect(sections.map(\.period) == [.today, .thisWeekend, .thisWeek, .later])
        #expect(sections.map { $0.events.map(\.id) } == [["today"], ["saturday"], ["thursday"], ["next-week"]])
    }
}

@MainActor
struct EventsViewModelTests {
    private func makeViewModel() -> EventsViewModel {
        EventsViewModel(service: LiveEventsService(repository: InMemoryEventsRepository(stored: events), dates: .fixed(now)), dates: .fixed(now), calendar: utc)
    }

    @Test func featuredOnlyShowsWithoutCategoryFilter() async {
        let viewModel = makeViewModel()
        await viewModel.load()
        #expect(viewModel.state.value?.featured.count == 2)

        viewModel.category = .film
        await viewModel.load()

        #expect(viewModel.state.value?.featured.isEmpty == true)
        #expect(viewModel.state.value?.sections.flatMap { $0.events.map(\.id) } == ["thursday", "next-week"])
    }

    @Test func searchClearsWhenTextIsEmpty() async {
        let viewModel = makeViewModel()
        viewModel.searchText = "outdoor"
        await viewModel.runSearch()
        #expect(viewModel.searchResults.map(\.id) == ["thursday"])

        viewModel.searchText = ""
        await viewModel.runSearch()

        #expect(viewModel.searchResults.isEmpty)
        #expect(!viewModel.isSearching)
    }

    @Test func eventMapsToCrossDomainDrafts() {
        let saturday = events[3]

        #expect(saturday.ticketed.eventID == "saturday")
        #expect(saturday.favoriteDraft.kind == .event)
        #expect(saturday.calendarDraft.sourceItemID == "saturday")
    }
}
