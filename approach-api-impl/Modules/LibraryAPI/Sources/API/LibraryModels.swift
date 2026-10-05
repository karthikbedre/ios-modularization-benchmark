import Foundation

public enum BookFormat: String, CaseIterable, Hashable, Sendable, Codable {
    case print, ebook, audiobook

    public var title: String {
        switch self {
        case .print: "Book"
        case .ebook: "eBook"
        case .audiobook: "Audiobook"
        }
    }

    /// Digital loans are shorter since they return themselves.
    public var loanDays: Int {
        self == .print ? 21 : 14
    }
}

public struct Book: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var title: String
    public var author: String
    public var isbn: String
    public var format: BookFormat
    public var year: Int
    public var subjects: [String]
    public var synopsis: String
    public var branchPlaceID: String
    public var branchName: String
    public var copies: Int

    public init(id: String, title: String, author: String, isbn: String, format: BookFormat, year: Int, subjects: [String], synopsis: String, branchPlaceID: String, branchName: String, copies: Int) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.format = format
        self.year = year
        self.subjects = subjects
        self.synopsis = synopsis
        self.branchPlaceID = branchPlaceID
        self.branchName = branchName
        self.copies = copies
    }
}

public struct BookAvailability: Hashable, Sendable {
    public var book: Book
    public var available: Int
    public var holdQueue: Int

    public init(book: Book, available: Int, holdQueue: Int) {
        self.book = book
        self.available = available
        self.holdQueue = holdQueue
    }

    public var isAvailable: Bool { available > 0 }
}

public struct Loan: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var bookID: String
    public var title: String
    public var author: String
    public var borrowedAt: Date
    public var dueDate: Date
    public var renewals: Int
    public var returnedAt: Date?

    public init(id: String, ownerID: String, bookID: String, title: String, author: String, borrowedAt: Date, dueDate: Date, renewals: Int, returnedAt: Date? = nil) {
        self.id = id
        self.ownerID = ownerID
        self.bookID = bookID
        self.title = title
        self.author = author
        self.borrowedAt = borrowedAt
        self.dueDate = dueDate
        self.renewals = renewals
        self.returnedAt = returnedAt
    }

    public var isOut: Bool { returnedAt == nil }

    public func isOverdue(at date: Date) -> Bool {
        isOut && dueDate < date
    }
}

public struct Hold: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var bookID: String
    public var title: String
    public var placedAt: Date

    public init(id: String, ownerID: String, bookID: String, title: String, placedAt: Date) {
        self.id = id
        self.ownerID = ownerID
        self.bookID = bookID
        self.title = title
        self.placedAt = placedAt
    }
}

public struct HoldStatus: Identifiable, Hashable, Sendable {
    public var hold: Hold
    /// 1 means next in line.
    public var position: Int
    public var isReady: Bool

    public init(hold: Hold, position: Int, isReady: Bool) {
        self.hold = hold
        self.position = position
        self.isReady = isReady
    }

    public var id: String { hold.id }
}

public enum LibraryError: Error, Hashable, Sendable {
    case bookNotFound
    case unavailable
    case alreadyBorrowed
    case loanLimitReached(Int)
    case loanNotFound
    case renewalLimitReached(Int)
    case overdue
    case othersWaiting
    case holdNotNeeded
    case alreadyOnHold
    case holdNotFound
}
