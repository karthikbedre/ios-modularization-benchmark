import Agenda
import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications

public struct LiveLibraryService: LibraryService {
    private let repository: any LibraryRepository
    private let identity: any IdentityService
    private let notifications: any NotificationsService
    private let agenda: any AgendaService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any LibraryRepository,
        identity: any IdentityService,
        notifications: any NotificationsService,
        agenda: any AgendaService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.prefix(8).lowercased() }
    ) {
        self.repository = repository
        self.identity = identity
        self.notifications = notifications
        self.agenda = agenda
        self.dates = dates
        self.makeID = makeID
    }

    public func search(_ text: String, format: BookFormat?) async throws -> [BookAvailability] {
        let snapshot = try await repository.load()
        let terms = text.split(separator: " ").map(String.init)
        return snapshot.books
            .filter { book in
                (format == nil || book.format == format) && terms.allSatisfy { term in
                    book.title.localizedStandardContains(term) || book.author.localizedStandardContains(term)
                        || book.isbn == term || book.subjects.contains { $0.localizedStandardContains(term) }
                }
            }
            .sorted { lhs, rhs in
                guard lhs.title == rhs.title else { return lhs.title < rhs.title }
                return BookFormat.allCases.firstIndex(of: lhs.format)! < BookFormat.allCases.firstIndex(of: rhs.format)!
            }
            .map { Circulation.availability(of: $0, in: snapshot) }
    }

    public func availability(bookID: String) async throws -> BookAvailability {
        let snapshot = try await repository.load()
        guard let book = snapshot.books.first(where: { $0.id == bookID }) else { throw LibraryError.bookNotFound }
        return Circulation.availability(of: book, in: snapshot)
    }

    public func loans() async throws -> [Loan] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load().loans.filter { $0.ownerID == ownerID && $0.isOut }.sorted { $0.dueDate < $1.dueDate }
    }

    public func holds() async throws -> [HoldStatus] {
        let ownerID = try await identity.currentUser().id
        let snapshot = try await repository.load()
        return snapshot.holds.filter { $0.ownerID == ownerID }.map { Circulation.status(of: $0, in: snapshot) }.sorted { $0.position < $1.position }
    }

    public func borrow(bookID: String) async throws -> Loan {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let id = "loan-\(makeID())"
        let loan = try await repository.update { snapshot in
            guard let book = snapshot.books.first(where: { $0.id == bookID }) else { throw LibraryError.bookNotFound }
            let ownLoans = snapshot.loans.filter { $0.ownerID == ownerID && $0.isOut }
            guard !ownLoans.contains(where: { $0.bookID == bookID }) else { throw LibraryError.alreadyBorrowed }
            guard ownLoans.count < Circulation.maxLoans else { throw LibraryError.loanLimitReached(Circulation.maxLoans) }
            guard Circulation.canBorrow(book, ownerID: ownerID, in: snapshot) else { throw LibraryError.unavailable }

            snapshot.holds.removeAll { $0.bookID == bookID && $0.ownerID == ownerID }
            let loan = Loan(id: id, ownerID: ownerID, bookID: book.id, title: book.title, author: book.author,
                            borrowedAt: now, dueDate: now.addingTimeInterval(TimeInterval(book.format.loanDays * 86_400)), renewals: 0)
            snapshot.loans.append(loan)
            return loan
        }
        await putDueDateOnAgenda(loan)
        return loan
    }

    public func renew(loanID: String) async throws -> Loan {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let loan = try await repository.update { snapshot in
            guard let index = snapshot.loans.firstIndex(where: { $0.id == loanID && $0.ownerID == ownerID && $0.isOut }) else { throw LibraryError.loanNotFound }
            let loan = snapshot.loans[index]
            guard !loan.isOverdue(at: now) else { throw LibraryError.overdue }
            guard loan.renewals < Circulation.maxRenewals else { throw LibraryError.renewalLimitReached(Circulation.maxRenewals) }
            guard Circulation.queue(for: loan.bookID, in: snapshot).isEmpty else { throw LibraryError.othersWaiting }
            let format = snapshot.books.first { $0.id == loan.bookID }?.format ?? .print
            snapshot.loans[index].dueDate = loan.dueDate.addingTimeInterval(TimeInterval(format.loanDays * 86_400))
            snapshot.loans[index].renewals += 1
            return snapshot.loans[index]
        }
        await removeDueDateFromAgenda(loan)
        await putDueDateOnAgenda(loan)
        return loan
    }

    public func giveBack(loanID: String) async throws {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let loan = try await repository.update { snapshot in
            guard let index = snapshot.loans.firstIndex(where: { $0.id == loanID && $0.ownerID == ownerID && $0.isOut }) else { throw LibraryError.loanNotFound }
            snapshot.loans[index].returnedAt = now
            return snapshot.loans[index]
        }
        await removeDueDateFromAgenda(loan)
    }

    public func placeHold(bookID: String) async throws -> HoldStatus {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let id = "hold-\(makeID())"
        let status = try await repository.update { snapshot in
            guard let book = snapshot.books.first(where: { $0.id == bookID }) else { throw LibraryError.bookNotFound }
            guard !snapshot.loans.contains(where: { $0.bookID == bookID && $0.ownerID == ownerID && $0.isOut }) else { throw LibraryError.alreadyBorrowed }
            guard !snapshot.holds.contains(where: { $0.bookID == bookID && $0.ownerID == ownerID }) else { throw LibraryError.alreadyOnHold }
            guard !Circulation.availability(of: book, in: snapshot).isAvailable else { throw LibraryError.holdNotNeeded }
            let hold = Hold(id: id, ownerID: ownerID, bookID: book.id, title: book.title, placedAt: now)
            snapshot.holds.append(hold)
            return Circulation.status(of: hold, in: snapshot)
        }
        _ = try? await notifications.post(NotificationDraft(
            title: status.isReady ? "Your hold is ready" : "Hold placed",
            body: status.isReady ? "\(status.hold.title) is waiting for you." : "You are number \(status.position) in line for \(status.hold.title).",
            category: .library,
            sourceDomain: "Library"
        ))
        return status
    }

    public func cancelHold(id: String) async throws {
        let ownerID = try await identity.currentUser().id
        try await repository.update { snapshot in
            guard snapshot.holds.contains(where: { $0.id == id && $0.ownerID == ownerID }) else { throw LibraryError.holdNotFound }
            snapshot.holds.removeAll { $0.id == id }
        }
    }

    public func summary() async -> DomainSummary {
        guard let loans = try? await loans(), let holds = try? await holds() else {
            return DomainSummary(title: "Library", detail: "Unavailable")
        }
        if let ready = holds.first(where: \.isReady) {
            return DomainSummary(title: "Library", detail: "\(ready.hold.title) is ready to pick up")
        }
        guard let next = loans.first else {
            return DomainSummary(title: "Library", detail: "No books out")
        }
        let days = Calendar.current.dateComponents([.day], from: dates.now, to: next.dueDate).day ?? 0
        let due = next.isOverdue(at: dates.now) ? "overdue" : days == 0 ? "due today" : "due in \(days) days"
        return DomainSummary(title: "Library", detail: "\(loans.count) out · \(next.title) \(due)")
    }

    /// The loan stands either way, so agenda failures are ignored.
    private func putDueDateOnAgenda(_ loan: Loan) async {
        _ = try? await agenda.add(CalendarDraft(
            title: "Return \(loan.title)", start: loan.dueDate.addingTimeInterval(-3600), end: loan.dueDate,
            location: nil, sourceDomain: "Library", sourceItemID: loan.id, reminder: .oneDay
        ))
    }

    private func removeDueDateFromAgenda(_ loan: Loan) async {
        guard let entry = try? await agenda.entry(sourceDomain: "Library", sourceItemID: loan.id) else { return }
        try? await agenda.remove(id: entry.id)
    }
}
