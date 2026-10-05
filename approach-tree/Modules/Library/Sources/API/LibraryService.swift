import CoreModels
import Foundation
import SwiftUI

public protocol LibraryService: SummaryProviding {
    func search(_ text: String, format: BookFormat?) async throws -> [BookAvailability]
    func availability(bookID: String) async throws -> BookAvailability
    func loans() async throws -> [Loan]
    func holds() async throws -> [HoldStatus]
    /// Borrows an available copy and puts the due date on the agenda.
    func borrow(bookID: String) async throws -> Loan
    func renew(loanID: String) async throws -> Loan
    func giveBack(loanID: String) async throws
    /// Joins the queue for a book with no copies left and confirms in the inbox.
    func placeHold(bookID: String) async throws -> HoldStatus
    func cancelHold(id: String) async throws
}

public struct LibraryEntryPoints: Sendable {
    public var book: @MainActor @Sendable (_ bookID: String) -> AnyView

    public init(book: @escaping @MainActor @Sendable (_ bookID: String) -> AnyView) {
        self.book = book
    }
}
