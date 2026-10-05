import CoreKit
import CoreModels
import FavoritesAPI
@testable import Favorites
import Foundation
import IdentityAPI
import Testing

private let now = Date(timeIntervalSince1970: 1_791_201_600)

private func item(_ id: String, _ kind: FavoriteKind, itemID: String, daysAgo: Double, owner: String = "user-1") -> FavoriteItem {
    FavoriteItem(id: id, ownerID: owner, kind: kind, itemID: itemID, title: id, subtitle: "", addedAt: now.addingTimeInterval(-daysAgo * 86_400))
}

private let items = [
    item("old-event", .event, itemID: "e1", daysAgo: 10),
    item("new-restaurant", .restaurant, itemID: "r1", daysAgo: 1),
    item("other-user", .event, itemID: "e2", daysAgo: 0, owner: "user-2"),
]

private struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: now)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

private func makeService(_ repository: InMemoryFavoritesRepository) -> LiveFavoritesService {
    LiveFavoritesService(repository: repository, identity: StubIdentityService(), dates: .fixed(now), makeID: { "fav-new" })
}

struct LiveFavoritesServiceTests {
    private let repository = InMemoryFavoritesRepository(items: items)

    @Test func listsOnlyTheResidentsFavoritesNewestFirst() async throws {
        let service = makeService(repository)

        #expect(try await service.favorites(of: nil).map(\.id) == ["new-restaurant", "old-event"])
        #expect(try await service.favorites(of: .event).map(\.id) == ["old-event"])
    }

    @Test func toggleAddsThenRemoves() async throws {
        let service = makeService(repository)
        let draft = FavoriteDraft(kind: .book, itemID: "b1", title: "The Overstory", subtitle: "Richard Powers")

        #expect(try await service.toggle(draft))
        #expect(try await service.isFavorite(kind: .book, itemID: "b1"))
        #expect(try await service.favorites(of: nil).first?.addedAt == now)

        #expect(try await !service.toggle(draft))
        #expect(try await !service.isFavorite(kind: .book, itemID: "b1"))
    }

    @Test func toggleDoesNotTouchAnotherResidentsFavorite() async throws {
        let service = makeService(repository)

        #expect(try await service.toggle(FavoriteDraft(kind: .event, itemID: "e2", title: "", subtitle: "")))
        #expect(await repository.items.count == 4)
    }

    @Test func toggleStopsAtTheLimit() async {
        let full = (0..<LiveFavoritesService.limit).map { item("f\($0)", .event, itemID: "e\($0)", daysAgo: 1) }
        let service = makeService(InMemoryFavoritesRepository(items: full))

        await #expect(throws: FavoritesError.limitReached(LiveFavoritesService.limit)) {
            try await service.toggle(FavoriteDraft(kind: .book, itemID: "b1", title: "", subtitle: ""))
        }
    }

    @Test func removeRejectsAnotherResidentsItem() async {
        let service = makeService(repository)

        await #expect(throws: FavoritesError.notFound) { try await service.remove(id: "other-user") }
    }

    @Test func bundledFavoritesDecode() async throws {
        let bundled = try await BundleFavoritesRepository(loader: MockDataLoader(latency: .none)).load()

        #expect(bundled.count == 5)
    }
}

@MainActor
struct FavoritesViewModelTests {
    @Test func groupsByKindInStableOrder() async {
        let viewModel = FavoritesViewModel(service: makeService(InMemoryFavoritesRepository(items: items)))

        await viewModel.load()

        #expect(viewModel.groups.map(\.kind) == [.event, .restaurant])
    }

    @Test func removeReloads() async {
        let viewModel = FavoritesViewModel(service: makeService(InMemoryFavoritesRepository(items: items)))
        await viewModel.load()

        await viewModel.remove(viewModel.state.value![0])

        #expect(viewModel.state.value?.map(\.id) == ["old-event"])
    }
}
