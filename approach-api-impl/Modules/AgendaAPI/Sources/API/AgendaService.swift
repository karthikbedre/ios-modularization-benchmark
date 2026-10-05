import CoreModels
import Foundation
import SwiftUI

public protocol AgendaService: SummaryProviding {
    func entries(in interval: DateInterval) async throws -> [CalendarEntry]
    func upcoming(limit: Int) async throws -> [CalendarEntry]
    /// Adds the entry and schedules its reminder notification.
    @discardableResult
    func add(_ draft: CalendarDraft) async throws -> CalendarEntry
    func entry(sourceDomain: String, sourceItemID: String) async throws -> CalendarEntry?
    func remove(id: String) async throws
}

public struct AgendaEntryPoints: Sendable {
    /// An "Add to calendar" button that turns into "Added" once the entry exists.
    public var addButton: @MainActor @Sendable (CalendarDraft) -> AnyView
    public var agenda: @MainActor @Sendable () -> AnyView

    public init(
        addButton: @escaping @MainActor @Sendable (CalendarDraft) -> AnyView,
        agenda: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.addButton = addButton
        self.agenda = agenda
    }
}
