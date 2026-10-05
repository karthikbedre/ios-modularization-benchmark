import CoreKit
import Foundation
import Observation

@MainActor
@Observable
final class InboxViewModel {
    private(set) var state: LoadState<[CityNotification]> = .idle
    var filter: InboxFilter = .all
    private(set) var errorMessage: String?

    let service: any NotificationsService
    private let dates: DateProvider

    init(service: any NotificationsService, dates: DateProvider = .live) {
        self.service = service
        self.dates = dates
    }

    var sections: [InboxSection] {
        InboxSection.make(state.value ?? [], filter: filter, now: dates.now)
    }

    var unreadCount: Int {
        state.value?.count { !$0.isRead } ?? 0
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await service.inbox())
        } catch {
            state = .failed("Your inbox could not be loaded.")
        }
    }

    func open(_ notification: CityNotification) async {
        guard !notification.isRead else { return }
        await perform { try await self.service.markRead(id: notification.id) }
    }

    func markAllRead() async {
        await perform { try await self.service.markAllRead() }
    }

    func delete(_ notification: CityNotification) async {
        await perform { try await self.service.delete(id: notification.id) }
    }

    private func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = "That change could not be saved."
        }
        await load()
    }
}
