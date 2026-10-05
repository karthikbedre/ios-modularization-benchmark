import CoreKit
import CoreModels
import Foundation
import Identity
import Wallet

public struct LiveTransitService: TransitService {
    private let repository: any TransitRepository
    private let identity: any IdentityService
    private let wallet: any WalletService
    private let dates: DateProvider
    private let calendar: Calendar
    private let makeID: @Sendable () -> String

    init(
        repository: any TransitRepository,
        identity: any IdentityService,
        wallet: any WalletService,
        dates: DateProvider = .live,
        calendar: Calendar = .current,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.prefix(8).lowercased() }
    ) {
        self.repository = repository
        self.identity = identity
        self.wallet = wallet
        self.dates = dates
        self.calendar = calendar
        self.makeID = makeID
    }

    public func lines() async throws -> [TransitLine] {
        try await repository.load().lines
    }

    public func stops() async throws -> [TransitStop] {
        try await repository.load().stops.sorted { $0.name < $1.name }
    }

    public func stop(id: String) async throws -> TransitStop {
        guard let stop = try await repository.load().stops.first(where: { $0.id == id }) else { throw TransitError.stopNotFound }
        return stop
    }

    public func departures(stopID: String, limit: Int) async throws -> [Departure] {
        let snapshot = try await repository.load()
        guard snapshot.stops.contains(where: { $0.id == stopID }) else { throw TransitError.stopNotFound }
        let names = Dictionary(uniqueKeysWithValues: snapshot.stops.map { ($0.id, $0.name) })
        let now = dates.now
        let departures = snapshot.lines.flatMap { line -> [Departure] in
            guard let index = line.stopIDs.firstIndex(of: stopID) else { return [] }
            return Timetable.runs(of: line, fromIndex: index, after: now, limit: limit, calendar: calendar).map { run in
                Departure(line: line, stopID: stopID, time: run.time, destination: names[line.stopIDs[run.towardIndex]] ?? "")
            }
        }
        return Array(departures.sorted { $0.time < $1.time }.prefix(limit))
    }

    public func planTrip(fromStopID: String, toStopID: String) async throws -> Trip {
        guard fromStopID != toStopID else { throw TransitError.sameStop }
        let snapshot = try await repository.load()
        let stops = Dictionary(uniqueKeysWithValues: snapshot.stops.map { ($0.id, $0) })
        guard let origin = stops[fromStopID], let destination = stops[toStopID] else { throw TransitError.stopNotFound }
        guard let trip = TripPlanner.plan(from: origin, to: destination, lines: snapshot.lines, stops: stops, after: dates.now, calendar: calendar) else {
            throw TransitError.noRoute
        }
        return trip
    }

    public func passOptions() async throws -> [PassOption] {
        try await repository.load().passOptions
    }

    public func passes() async throws -> [TransitPass] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load().passes.filter { $0.ownerID == ownerID }.sorted { $0.validUntil > $1.validUntil }
    }

    public func buyPass(_ kind: PassKind) async throws -> TransitPass {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let snapshot = try await repository.load()
        if kind != .single, let valid = snapshot.passes.first(where: { $0.ownerID == ownerID && $0.kind == kind && $0.isValid(at: now) }) {
            throw TransitError.passStillValid(until: valid.validUntil)
        }
        guard let option = snapshot.passOptions.first(where: { $0.kind == kind }) else { throw TransitError.noRoute }

        let receipt = try await wallet.pay(PaymentRequest(merchant: "City Transit", category: .transit, amount: option.price, reference: kind.title), methodID: nil)
        let pass = TransitPass(id: "pass-\(makeID())", ownerID: ownerID, kind: kind, validFrom: now, validUntil: now.addingTimeInterval(kind.validity),
                               price: option.price, transactionID: receipt.transactionID)
        try await repository.update { $0.passes.append(pass) }
        return pass
    }

    public func summary() async -> DomainSummary {
        let now = dates.now
        if let pass = try? await passes().first(where: { $0.isValid(at: now) }) {
            return DomainSummary(title: "Transit", detail: "\(pass.kind.title) valid until \(pass.validUntil.formatted(date: .abbreviated, time: .shortened))")
        }
        guard let next = try? await departures(stopID: "stop-central", limit: 1).first else {
            return DomainSummary(title: "Transit", detail: "No pass")
        }
        let minutes = max(0, Int(next.time.timeIntervalSince(now) / 60))
        return DomainSummary(title: "Transit", detail: "\(next.line.name) from Central Station in \(minutes) min")
    }
}
