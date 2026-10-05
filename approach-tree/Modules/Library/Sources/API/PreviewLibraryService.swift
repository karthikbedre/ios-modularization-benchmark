#if DEBUG
import CoreModels
import Foundation

extension Book {
    public static let preview = Book(
        id: "book-overstory", title: "The Overstory", author: "Richard Powers", isbn: "9780393635522", format: .print, year: 2018,
        subjects: ["Fiction", "Trees"], synopsis: "Nine strangers are drawn together by trees.", branchPlaceID: "place-lib-central",
        branchName: "Central Library", copies: 3
    )
}

public struct PreviewLibraryService: LibraryService {
    public init() {}

    public func search(_ text: String, format: BookFormat?) async throws -> [BookAvailability] {
        [BookAvailability(book: .preview, available: 1, holdQueue: 0)]
    }

    public func availability(bookID: String) async throws -> BookAvailability {
        BookAvailability(book: .preview, available: 1, holdQueue: 0)
    }

    public func loans() async throws -> [Loan] {
        [Loan(id: "l1", ownerID: "user-preview", bookID: "book-overstory", title: "The Overstory", author: "Richard Powers",
              borrowedAt: .now.addingTimeInterval(-10 * 86_400), dueDate: .now.addingTimeInterval(4 * 86_400), renewals: 0)]
    }

    public func holds() async throws -> [HoldStatus] { [] }
    public func borrow(bookID: String) async throws -> Loan { try await loans()[0] }
    public func renew(loanID: String) async throws -> Loan { try await loans()[0] }
    public func giveBack(loanID: String) async throws {}

    public func placeHold(bookID: String) async throws -> HoldStatus {
        HoldStatus(hold: Hold(id: "h", ownerID: "user-preview", bookID: bookID, title: "The Overstory", placedAt: .now), position: 2, isReady: false)
    }

    public func cancelHold(id: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Library", detail: "1 loan due in 4 days")
    }
}
#endif
