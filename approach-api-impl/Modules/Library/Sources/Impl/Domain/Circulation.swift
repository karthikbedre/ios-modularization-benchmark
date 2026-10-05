import Foundation
import LibraryAPI

/// Copy accounting. Free copies go to the hold queue first, in order, before anyone can walk in and borrow.
enum Circulation {
    static let maxLoans = 10
    static let maxRenewals = 2

    static func freeCopies(of book: Book, in snapshot: LibrarySnapshot) -> Int {
        max(0, book.copies - snapshot.loans.count { $0.bookID == book.id && $0.isOut })
    }

    static func queue(for bookID: String, in snapshot: LibrarySnapshot) -> [Hold] {
        snapshot.holds.filter { $0.bookID == bookID }.sorted { $0.placedAt < $1.placedAt }
    }

    static func availability(of book: Book, in snapshot: LibrarySnapshot) -> BookAvailability {
        let queue = queue(for: book.id, in: snapshot)
        return BookAvailability(book: book, available: max(0, freeCopies(of: book, in: snapshot) - queue.count), holdQueue: queue.count)
    }

    static func status(of hold: Hold, in snapshot: LibrarySnapshot) -> HoldStatus {
        let position = (queue(for: hold.bookID, in: snapshot).firstIndex { $0.id == hold.id } ?? 0) + 1
        let free = snapshot.books.first { $0.id == hold.bookID }.map { freeCopies(of: $0, in: snapshot) } ?? 0
        return HoldStatus(hold: hold, position: position, isReady: position <= free)
    }

    /// Whether `ownerID` may take a copy now, either walking in or collecting a ready hold.
    static func canBorrow(_ book: Book, ownerID: String, in snapshot: LibrarySnapshot) -> Bool {
        if availability(of: book, in: snapshot).isAvailable { return true }
        guard let hold = snapshot.holds.first(where: { $0.bookID == book.id && $0.ownerID == ownerID }) else { return false }
        return status(of: hold, in: snapshot).isReady
    }
}
