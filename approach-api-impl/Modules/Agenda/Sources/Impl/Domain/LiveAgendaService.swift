import AgendaAPI
import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI

public struct LiveAgendaService: AgendaService {
    private let repository: any AgendaRepository
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any AgendaRepository,
        identity: any IdentityService,
        notifications: any NotificationsService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { "cal-\(UUID().uuidString.prefix(8))" }
    ) {
        self.repository = repository
        self.identity = identity
        self.notifications = notifications
        self.dates = dates
        self.makeID = makeID
    }

    public func entries(in interval: DateInterval) async throws -> [CalendarEntry] {
        try await ownEntries().filter { interval.intersects(DateInterval(start: $0.start, end: $0.end)) }
    }

    public func upcoming(limit: Int) async throws -> [CalendarEntry] {
        let now = dates.now
        return Array(try await ownEntries().filter { $0.end > now }.prefix(limit))
    }

    @discardableResult
    public func add(_ draft: CalendarDraft) async throws -> CalendarEntry {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw AgendaError.emptyTitle }
        guard draft.end > draft.start else { throw AgendaError.endsBeforeStart }
        let ownerID = try await identity.currentUser().id
        let id = makeID()

        let entry = try await repository.update { entries in
            if let itemID = draft.sourceItemID,
               entries.contains(where: { $0.ownerID == ownerID && $0.sourceDomain == draft.sourceDomain && $0.sourceItemID == itemID }) {
                throw AgendaError.alreadyAdded
            }
            let entry = CalendarEntry(
                id: id, ownerID: ownerID, title: title, start: draft.start, end: draft.end, location: draft.location,
                sourceDomain: draft.sourceDomain, sourceItemID: draft.sourceItemID, reminder: draft.reminder
            )
            entries.append(entry)
            return entry
        }
        try await scheduleReminder(for: entry)
        return entry
    }

    public func entry(sourceDomain: String, sourceItemID: String) async throws -> CalendarEntry? {
        try await ownEntries().first { $0.sourceDomain == sourceDomain && $0.sourceItemID == sourceItemID }
    }

    public func remove(id: String) async throws {
        let ownerID = try await identity.currentUser().id
        try await repository.update { entries in
            guard entries.contains(where: { $0.id == id && $0.ownerID == ownerID }) else {
                throw AgendaError.notFound
            }
            entries.removeAll { $0.id == id }
        }
    }

    public func summary() async -> DomainSummary {
        guard let next = try? await upcoming(limit: 1).first else {
            return DomainSummary(title: "Agenda", detail: "Nothing coming up")
        }
        return DomainSummary(title: "Agenda", detail: "Next: \(next.title), \(next.start.formatted(.dateTime.weekday().hour().minute()))")
    }

    private func ownEntries() async throws -> [CalendarEntry] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load()
            .filter { $0.ownerID == ownerID }
            .sorted { $0.start < $1.start }
    }

    /// Reminders that would already be in the past are skipped rather than delivered late.
    private func scheduleReminder(for entry: CalendarEntry) async throws {
        guard entry.reminder != .none else { return }
        let deliverAt = entry.start.addingTimeInterval(-entry.reminder.interval)
        guard deliverAt > dates.now else { return }
        try await notifications.post(NotificationDraft(
            title: entry.title,
            body: "Starts \(entry.start.formatted(date: .abbreviated, time: .shortened))" + (entry.location.map { " at \($0)" } ?? ""),
            category: .reminder,
            sourceDomain: "Agenda",
            deliverAt: deliverAt
        ))
    }
}
