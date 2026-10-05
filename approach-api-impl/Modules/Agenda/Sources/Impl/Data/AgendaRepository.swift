import AgendaAPI
import CoreKit
import Foundation

protocol AgendaRepository: Sendable {
    func load() async throws -> [CalendarEntry]
    func update<Result: Sendable>(_ change: @Sendable (inout [CalendarEntry]) throws -> Result) async throws -> Result
}

actor BundleAgendaRepository: AgendaRepository {
    private let loader: MockDataLoader
    private var cached: [CalendarEntry]?

    init(loader: MockDataLoader) {
        self.loader = loader
    }

    func load() async throws -> [CalendarEntry] {
        if let cached { return cached }
        let entries = try await loader.load([CalendarEntry].self, resource: "agenda", in: .module)
        if let cached { return cached }
        cached = entries
        return entries
    }

    func update<Result: Sendable>(_ change: @Sendable (inout [CalendarEntry]) throws -> Result) async throws -> Result {
        var entries = try await load()
        let result = try change(&entries)
        cached = entries
        return result
    }
}

actor InMemoryAgendaRepository: AgendaRepository {
    private(set) var entries: [CalendarEntry]

    init(entries: [CalendarEntry]) {
        self.entries = entries
    }

    func load() async throws -> [CalendarEntry] { entries }

    func update<Result: Sendable>(_ change: @Sendable (inout [CalendarEntry]) throws -> Result) async throws -> Result {
        try change(&entries)
    }
}
