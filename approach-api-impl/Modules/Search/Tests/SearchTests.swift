import CoreModels
import DiningAPI
import EventsAPI
import Foundation
import LibraryAPI
import PlacesAPI
@testable import Search
import SearchAPI
import Testing
import TransitAPI

private struct Failure: Error {}

private struct StubEvents: EventsService {
    var fails = false
    func upcoming(category: EventCategory?) async throws -> [CityEvent] { [] }
    func featured() async throws -> [CityEvent] { [] }
    func event(id: String) async throws -> CityEvent { throw EventsError.notFound }

    func search(_ text: String) async throws -> [CityEvent] {
        if fails { throw Failure() }
        return [CityEvent(id: "e1", title: "Harbor Jazz", summary: "", category: .music, start: .distantFuture, end: .distantFuture,
                          venuePlaceID: "p", venueName: "Amphitheater", organizer: "", priceFrom: nil, isFeatured: false, tags: [])]
    }

    func summary() async -> DomainSummary { DomainSummary(title: "", detail: "") }
}

private struct StubDining: DiningService {
    func restaurants(matching filter: DiningFilter) async throws -> [Restaurant] { [] }
    func restaurant(id: String) async throws -> Restaurant { throw DiningError.notFound }
    func menu(restaurantID: String) async throws -> [MenuSection] { [] }

    func search(_ text: String) async throws -> [Restaurant] {
        [Restaurant(id: "r1", name: "Tidewater Grill", cuisine: .seafood, priceLevel: 3, rating: 4, reviewCount: 1, placeID: "p",
                    district: "Harborfront", openingHours: "", acceptsReservations: true, highlights: [])]
    }

    func summary() async -> DomainSummary { DomainSummary(title: "", detail: "") }
}

private struct StubLibrary: LibraryService {
    func search(_ text: String, format: BookFormat?) async throws -> [BookAvailability] { [] }
    func availability(bookID: String) async throws -> BookAvailability { throw LibraryError.bookNotFound }
    func loans() async throws -> [Loan] { [] }
    func holds() async throws -> [HoldStatus] { [] }
    func borrow(bookID: String) async throws -> Loan { throw LibraryError.bookNotFound }
    func renew(loanID: String) async throws -> Loan { throw LibraryError.loanNotFound }
    func giveBack(loanID: String) async throws {}
    func placeHold(bookID: String) async throws -> HoldStatus { throw LibraryError.bookNotFound }
    func cancelHold(id: String) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "", detail: "") }
}

private struct StubTransit: TransitService {
    func lines() async throws -> [TransitLine] { [] }

    func stops() async throws -> [TransitStop] {
        [TransitStop(id: "s1", name: "Harbor Station", location: GeoPoint(latitude: 0, longitude: 0)),
         TransitStop(id: "s2", name: "Central Station", location: GeoPoint(latitude: 0, longitude: 0))]
    }

    func stop(id: String) async throws -> TransitStop { throw TransitError.stopNotFound }
    func departures(stopID: String, limit: Int) async throws -> [Departure] { [] }
    func planTrip(fromStopID: String, toStopID: String) async throws -> Trip { throw TransitError.noRoute }
    func passOptions() async throws -> [PassOption] { [] }
    func passes() async throws -> [TransitPass] { [] }
    func buyPass(_ kind: PassKind) async throws -> TransitPass { throw TransitError.noRoute }
    func summary() async -> DomainSummary { DomainSummary(title: "", detail: "") }
}

private struct StubPlaces: PlacesService {
    func places(in category: PlaceCategory?) async throws -> [Place] {
        [Place(id: "p1", name: "Harbor Green", category: .park, location: GeoPoint(latitude: 0, longitude: 0),
               address: Address(street: "", district: "Harborfront", postalCode: "")),
         Place(id: "p2", name: "City Hall", category: .civicOffice, location: GeoPoint(latitude: 0, longitude: 0),
               address: Address(street: "", district: "Old Town", postalCode: ""))]
    }

    func place(id: String) async throws -> Place { throw PlacesError.notFound }
    func nearby(_ point: GeoPoint, radius: Measurement<UnitLength>, category: PlaceCategory?) async throws -> [NearbyPlace] { [] }
    func distance(from: GeoPoint, to: GeoPoint) -> Measurement<UnitLength> { Measurement(value: 0, unit: .meters) }
    func summary() async -> DomainSummary { DomainSummary(title: "", detail: "") }
}

private func makeService(eventsFail: Bool = false) -> LiveSearchService {
    LiveSearchService(events: StubEvents(fails: eventsFail), dining: StubDining(), library: StubLibrary(), transit: StubTransit(), places: StubPlaces())
}

struct SearchRankingTests {
    private func result(_ scope: SearchScope, _ title: String) -> SearchResult {
        SearchResult(scope: scope, itemID: title, title: title, subtitle: "")
    }

    @Test(arguments: [("Harbor Green", 0), ("Old Harbor", 1), ("Seaharbor", 2), ("Elsewhere", 3)])
    func scoresTitleMatches(title: String, expected: Int) {
        #expect(SearchRanking.score(result(.places, title), for: " harbor ") == expected)
    }

    @Test func groupsByScopeThenScoreThenTitle() {
        let ranked = SearchRanking.rank([
            result(.places, "Old Harbor"), result(.events, "Seaharbor Fest"), result(.places, "Harbor Green"), result(.places, "Harbor Arch"),
        ], for: "harbor")

        #expect(ranked.map(\.title) == ["Seaharbor Fest", "Harbor Arch", "Harbor Green", "Old Harbor"])
    }
}

struct LiveSearchServiceTests {
    @Test func fansOutToEveryScopeAndRanks() async {
        let response = await makeService().search("harbor", in: Set(SearchScope.allCases))

        #expect(response.results.map(\.id) == ["events-e1", "restaurants-r1", "stops-s1", "places-p1"])
        #expect(response.unavailable.isEmpty)
    }

    @Test func respectsSelectedScopes() async {
        let response = await makeService().search("harbor", in: [.stops])

        #expect(response.results.map(\.itemID) == ["s1"])
    }

    @Test func failingSourceIsReportedButDoesNotHideOthers() async {
        let response = await makeService(eventsFail: true).search("harbor", in: [.events, .places])

        #expect(response.results.map(\.itemID) == ["p1"])
        #expect(response.unavailable == [.events])
    }

    @Test func tooShortQueriesReturnNothing() async {
        #expect(await makeService().search(" h ", in: Set(SearchScope.allCases)).results.isEmpty)
    }
}

struct RecentQueriesStoreTests {
    @Test func keepsMostRecentFirstWithoutDuplicates() async {
        let store = RecentQueriesStore()

        for query in ["jazz", "Harbor", " ", "harbor"] + (1...10).map({ "q\($0)" }) {
            await store.record(query)
        }

        let queries = await store.queries
        #expect(queries.count == RecentQueriesStore.limit)
        #expect(queries.first == "q10")
        #expect(!queries.contains("jazz"))
    }

    @Test func dedupeIsCaseInsensitive() async {
        let store = RecentQueriesStore()
        await store.record("Harbor")
        await store.record("harbor")

        #expect(await store.queries == ["harbor"])
    }
}

@MainActor
struct SearchViewModelTests {
    @Test func atLeastOneScopeStaysSelected() {
        let viewModel = SearchViewModel(service: makeService())
        for scope in SearchScope.allCases { viewModel.toggle(scope) }

        #expect(viewModel.scopes == [.places])
    }

    @Test func submitRecordsAndGroupsFollowScopeOrder() async {
        let viewModel = SearchViewModel(service: makeService())
        viewModel.query = "harbor"

        await viewModel.search()
        await viewModel.submit()

        #expect(viewModel.groups.map(\.scope) == [.events, .restaurants, .stops, .places])
        #expect(viewModel.recent == ["harbor"])
    }
}
