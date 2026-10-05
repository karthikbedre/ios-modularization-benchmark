import AgendaAPI
import CoreModels
import Foundation
import IdentityAPI
@testable import Library
import LibraryAPI
import NotificationsAPI
import Testing

private let now = Date(timeIntervalSince1970: 1_791_201_600)
private let day: TimeInterval = 86_400

private func book(_ id: String, copies: Int, format: BookFormat = .print, title: String? = nil, subjects: [String] = []) -> Book {
    Book(id: id, title: title ?? id, author: "Author \(id)", isbn: "isbn-\(id)", format: format, year: 2000, subjects: subjects,
         synopsis: "", branchPlaceID: "p", branchName: "Central", copies: copies)
}

private func loan(_ id: String, bookID: String, owner: String = "user-1", dueIn days: Double = 7, renewals: Int = 0) -> Loan {
    Loan(id: id, ownerID: owner, bookID: bookID, title: bookID, author: "", borrowedAt: now.addingTimeInterval(-7 * day),
         dueDate: now.addingTimeInterval(days * day), renewals: renewals)
}

private func hold(_ id: String, bookID: String, owner: String, placedDaysAgo: Double) -> Hold {
    Hold(id: id, ownerID: owner, bookID: bookID, title: bookID, placedAt: now.addingTimeInterval(-placedDaysAgo * day))
}

private struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: now)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

private actor RecordingNotificationsService: NotificationsService {
    private(set) var posted: [NotificationDraft] = []

    func inbox() async throws -> [CityNotification] { [] }
    func unreadCount() async throws -> Int { 0 }
    func markRead(id: String) async throws {}
    func markAllRead() async throws {}
    func delete(id: String) async throws {}

    func post(_ draft: NotificationDraft) async throws -> CityNotification {
        posted.append(draft)
        return CityNotification(id: "n", recipientID: "user-1", title: draft.title, body: draft.body, date: now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}

/// Keeps entries so the service can find and remove them again, like the real agenda.
private actor FakeAgendaService: AgendaService {
    private(set) var entries: [CalendarEntry] = []

    func entries(in interval: DateInterval) async throws -> [CalendarEntry] { entries }
    func upcoming(limit: Int) async throws -> [CalendarEntry] { entries }

    func add(_ draft: CalendarDraft) async throws -> CalendarEntry {
        let entry = CalendarEntry(id: "c\(entries.count)", ownerID: "user-1", title: draft.title, start: draft.start, end: draft.end,
                                  location: draft.location, sourceDomain: draft.sourceDomain, sourceItemID: draft.sourceItemID, reminder: draft.reminder)
        entries.append(entry)
        return entry
    }

    func entry(sourceDomain: String, sourceItemID: String) async throws -> CalendarEntry? {
        entries.first { $0.sourceDomain == sourceDomain && $0.sourceItemID == sourceItemID }
    }

    func remove(id: String) async throws {
        entries.removeAll { $0.id == id }
    }

    func summary() async -> DomainSummary { DomainSummary(title: "Agenda", detail: "") }
}

private struct Harness {
    let repository: InMemoryLibraryRepository
    let notifications = RecordingNotificationsService()
    let agenda = FakeAgendaService()

    init(books: [Book], loans: [Loan] = [], holds: [Hold] = []) {
        repository = InMemoryLibraryRepository(snapshot: LibrarySnapshot(books: books, loans: loans, holds: holds))
    }

    var service: LiveLibraryService {
        LiveLibraryService(repository: repository, identity: StubIdentityService(), notifications: notifications, agenda: agenda, dates: .fixed(now), makeID: { "1" })
    }
}

struct CirculationTests {
    @Test func freeCopiesGoToTheQueueBeforeWalkIns() {
        let snapshot = LibrarySnapshot(
            books: [book("b", copies: 2)],
            loans: [loan("l", bookID: "b", owner: "user-9")],
            holds: [hold("h1", bookID: "b", owner: "user-2", placedDaysAgo: 2), hold("h2", bookID: "b", owner: "user-1", placedDaysAgo: 1)]
        )

        let availability = Circulation.availability(of: snapshot.books[0], in: snapshot)

        #expect(availability.available == 0)
        #expect(availability.holdQueue == 2)
        #expect(Circulation.status(of: snapshot.holds[0], in: snapshot) == HoldStatus(hold: snapshot.holds[0], position: 1, isReady: true))
        #expect(Circulation.status(of: snapshot.holds[1], in: snapshot).isReady == false)
        #expect(!Circulation.canBorrow(snapshot.books[0], ownerID: "user-1", in: snapshot))
        #expect(Circulation.canBorrow(snapshot.books[0], ownerID: "user-2", in: snapshot))
    }
}

struct LiveLibraryServiceTests {
    @Test func searchMatchesEveryTermAndFiltersFormat() async throws {
        let harness = Harness(books: [
            book("dune", copies: 1, title: "Dune", subjects: ["Science fiction"]),
            book("dune-audio", copies: 1, format: .audiobook, title: "Dune"),
            book("cities", copies: 1, title: "Great Cities", subjects: ["Urban planning"]),
        ])

        #expect(try await harness.service.search("dune", format: nil).map(\.book.id) == ["dune", "dune-audio"])
        #expect(try await harness.service.search("dune", format: .audiobook).map(\.book.id) == ["dune-audio"])
        #expect(try await harness.service.search("urban planning", format: nil).map(\.book.id) == ["cities"])
    }

    @Test func borrowingSetsDueDateByFormatAndAddsItToTheAgenda() async throws {
        let harness = Harness(books: [book("e", copies: 1, format: .ebook)])

        let loan = try await harness.service.borrow(bookID: "e")

        #expect(loan.dueDate == now.addingTimeInterval(14 * day))
        #expect(await harness.agenda.entries.map(\.sourceItemID) == [loan.id])
        await #expect(throws: LibraryError.alreadyBorrowed) { try await harness.service.borrow(bookID: "e") }
    }

    @Test func noFreeCopyMeansHoldInstead() async throws {
        let harness = Harness(books: [book("b", copies: 1)], loans: [loan("l", bookID: "b", owner: "user-2")])

        await #expect(throws: LibraryError.unavailable) { try await harness.service.borrow(bookID: "b") }
        let status = try await harness.service.placeHold(bookID: "b")

        #expect(status.position == 1)
        #expect(!status.isReady)
        #expect(await harness.notifications.posted.map(\.title) == ["Hold placed"])
        await #expect(throws: LibraryError.alreadyOnHold) { try await harness.service.placeHold(bookID: "b") }
    }

    @Test func holdIsRejectedWhenACopyIsAvailable() async {
        let harness = Harness(books: [book("b", copies: 1)])

        await #expect(throws: LibraryError.holdNotNeeded) { try await harness.service.placeHold(bookID: "b") }
    }

    @Test func readyHoldIsCollectedByBorrowing() async throws {
        let harness = Harness(books: [book("b", copies: 1)], holds: [hold("mine", bookID: "b", owner: "user-1", placedDaysAgo: 1)])
        #expect(try await harness.service.holds().first?.isReady == true)

        _ = try await harness.service.borrow(bookID: "b")

        #expect(try await harness.service.holds().isEmpty)
    }

    @Test func renewMovesTheDueDateAndTheAgendaEntry() async throws {
        let harness = Harness(books: [book("b", copies: 2)])
        let loan = try await harness.service.borrow(bookID: "b")

        let renewed = try await harness.service.renew(loanID: loan.id)

        #expect(renewed.dueDate == loan.dueDate.addingTimeInterval(21 * day))
        #expect(renewed.renewals == 1)
        let entries = await harness.agenda.entries
        #expect(entries.count == 1)
        #expect(entries.first?.end == renewed.dueDate)
    }

    @Test func renewalRules() async {
        let harness = Harness(
            books: [book("a", copies: 1), book("b", copies: 1), book("c", copies: 1)],
            loans: [loan("overdue", bookID: "a", dueIn: -1), loan("maxed", bookID: "b", renewals: 2), loan("wanted", bookID: "c")],
            holds: [hold("h", bookID: "c", owner: "user-2", placedDaysAgo: 1)]
        )

        await #expect(throws: LibraryError.overdue) { try await harness.service.renew(loanID: "overdue") }
        await #expect(throws: LibraryError.renewalLimitReached(2)) { try await harness.service.renew(loanID: "maxed") }
        await #expect(throws: LibraryError.othersWaiting) { try await harness.service.renew(loanID: "wanted") }
    }

    @Test func returningFreesTheCopyAndClearsTheAgenda() async throws {
        let harness = Harness(books: [book("b", copies: 1)])
        let loan = try await harness.service.borrow(bookID: "b")

        try await harness.service.giveBack(loanID: loan.id)

        #expect(try await harness.service.loans().isEmpty)
        #expect(try await harness.service.availability(bookID: "b").isAvailable)
        #expect(await harness.agenda.entries.isEmpty)
    }

    @Test func loanLimitIsEnforced() async {
        let books = (0...Circulation.maxLoans).map { book("b\($0)", copies: 1) }
        let loans = (0..<Circulation.maxLoans).map { loan("l\($0)", bookID: "b\($0)") }
        let harness = Harness(books: books, loans: loans)

        await #expect(throws: LibraryError.loanLimitReached(10)) { try await harness.service.borrow(bookID: "b10") }
    }

    @Test func summaryPrefersAReadyHold() async {
        let harness = Harness(books: [book("b", copies: 1), book("c", copies: 1)], loans: [loan("l", bookID: "c", dueIn: 3)],
                              holds: [hold("h", bookID: "b", owner: "user-1", placedDaysAgo: 1)])

        #expect(await harness.service.summary().detail == "b is ready to pick up")
    }
}
