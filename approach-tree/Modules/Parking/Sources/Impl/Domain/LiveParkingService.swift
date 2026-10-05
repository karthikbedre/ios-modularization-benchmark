import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications
import Wallet

public struct LiveParkingService: ParkingService {
    static let reminderLead: TimeInterval = 10 * 60

    private let repository: any ParkingRepository
    private let identity: any IdentityService
    private let wallet: any WalletService
    private let notifications: any NotificationsService
    private let dates: DateProvider
    private let makeID: @Sendable () -> String

    init(
        repository: any ParkingRepository,
        identity: any IdentityService,
        wallet: any WalletService,
        notifications: any NotificationsService,
        dates: DateProvider = .live,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString.prefix(8).lowercased() }
    ) {
        self.repository = repository
        self.identity = identity
        self.wallet = wallet
        self.notifications = notifications
        self.dates = dates
        self.makeID = makeID
    }

    public func zones() async throws -> [ZoneAvailability] {
        let snapshot = try await repository.load()
        let now = dates.now
        return snapshot.zones
            .map { ZoneAvailability(zone: $0, availableSpots: Self.available($0, in: snapshot, at: now)) }
            .sorted { $0.zone.name < $1.zone.name }
    }

    public func vehicles() async throws -> [Vehicle] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load().vehicles.filter { $0.ownerID == ownerID }
    }

    public func addVehicle(plate: String, nickname: String) async throws -> Vehicle {
        let normalized = try PlateValidator.normalize(plate)
        let ownerID = try await identity.currentUser().id
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await repository.update { snapshot in
            guard !snapshot.vehicles.contains(where: { $0.plate == normalized && $0.ownerID == ownerID }) else {
                throw ParkingError.duplicateVehicle
            }
            let vehicle = Vehicle(plate: normalized, nickname: name.isEmpty ? normalized : name, ownerID: ownerID)
            snapshot.vehicles.append(vehicle)
            return vehicle
        }
    }

    public func removeVehicle(plate: String) async throws {
        let ownerID = try await identity.currentUser().id
        try await repository.update { snapshot in
            guard snapshot.vehicles.contains(where: { $0.plate == plate && $0.ownerID == ownerID }) else { throw ParkingError.unknownVehicle }
            snapshot.vehicles.removeAll { $0.plate == plate && $0.ownerID == ownerID }
        }
    }

    public func activeSessions() async throws -> [ParkingSession] {
        let now = dates.now
        return try await own().filter { $0.isActive(at: now) }.sorted { $0.end < $1.end }
    }

    public func history() async throws -> [ParkingSession] {
        let now = dates.now
        return try await own().filter { $0.end <= now }.sorted { $0.start > $1.start }
    }

    public func quote(zoneID: String, hours: Int) async throws -> ParkingQuote {
        let snapshot = try await repository.load()
        guard let zone = snapshot.zones.first(where: { $0.id == zoneID }) else { throw ParkingError.zoneNotFound }
        guard (1...zone.maxHours).contains(hours) else { throw ParkingError.hoursOutOfRange(max: zone.maxHours) }
        return ParkingQuote(zoneID: zoneID, hours: hours, cost: zone.hourlyRate * hours, end: dates.now.addingTimeInterval(Double(hours) * 3600))
    }

    public func start(zoneID: String, plate: String, hours: Int) async throws -> ParkingSession {
        let ownerID = try await identity.currentUser().id
        let quote = try await quote(zoneID: zoneID, hours: hours)
        let now = dates.now
        let id = "park-\(makeID())"

        // Claim the spot before paying so two residents cannot pay for the last one.
        let pending = try await repository.update { snapshot in
            guard let zone = snapshot.zones.first(where: { $0.id == zoneID }) else { throw ParkingError.zoneNotFound }
            guard snapshot.vehicles.contains(where: { $0.plate == plate && $0.ownerID == ownerID }) else { throw ParkingError.unknownVehicle }
            guard !snapshot.sessions.contains(where: { $0.plate == plate && $0.isActive(at: now) }) else { throw ParkingError.vehicleAlreadyParked }
            guard Self.available(zone, in: snapshot, at: now) > 0 else { throw ParkingError.zoneFull }
            let session = ParkingSession(id: id, ownerID: ownerID, zoneID: zone.id, zoneName: zone.name, plate: plate,
                                         start: now, end: quote.end, cost: quote.cost, transactionIDs: [])
            snapshot.sessions.append(session)
            return session
        }

        let receipt: PaymentReceipt
        do {
            receipt = try await wallet.pay(PaymentRequest(merchant: pending.zoneName, category: .parking, amount: quote.cost, reference: "\(plate), \(hours) h"), methodID: nil)
        } catch {
            _ = try? await repository.update { $0.sessions.removeAll { $0.id == id } }
            throw error
        }

        let reminderID = await scheduleReminder(zoneName: pending.zoneName, plate: plate, end: pending.end)
        return try await repository.update { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == id }) else { throw ParkingError.sessionNotFound }
            snapshot.sessions[index].transactionIDs = [receipt.transactionID]
            snapshot.sessions[index].reminderNotificationID = reminderID
            return snapshot.sessions[index]
        }
    }

    public func extend(sessionID: String, by hours: Int) async throws -> ParkingSession {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let snapshot = try await repository.load()
        guard let session = snapshot.sessions.first(where: { $0.id == sessionID && $0.ownerID == ownerID }) else { throw ParkingError.sessionNotFound }
        guard session.isActive(at: now) else { throw ParkingError.sessionEnded }
        guard let zone = snapshot.zones.first(where: { $0.id == session.zoneID }) else { throw ParkingError.zoneNotFound }
        let bookedHours = Int((session.end.timeIntervalSince(session.start) / 3600).rounded(.up))
        let remaining = zone.maxHours - bookedHours
        guard hours >= 1, hours <= remaining else { throw ParkingError.hoursOutOfRange(max: max(0, remaining)) }

        let cost = zone.hourlyRate * hours
        let receipt = try await wallet.pay(PaymentRequest(merchant: zone.name, category: .parking, amount: cost, reference: "\(session.plate), +\(hours) h"), methodID: nil)
        if let old = session.reminderNotificationID {
            try? await notifications.delete(id: old)
        }
        let newEnd = session.end.addingTimeInterval(Double(hours) * 3600)
        let reminderID = await scheduleReminder(zoneName: zone.name, plate: session.plate, end: newEnd)

        return try await repository.update { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == sessionID }) else { throw ParkingError.sessionNotFound }
            snapshot.sessions[index].end = newEnd
            snapshot.sessions[index].cost = snapshot.sessions[index].cost + cost
            snapshot.sessions[index].transactionIDs.append(receipt.transactionID)
            snapshot.sessions[index].reminderNotificationID = reminderID
            return snapshot.sessions[index]
        }
    }

    public func end(sessionID: String) async throws {
        let ownerID = try await identity.currentUser().id
        let now = dates.now
        let reminderID = try await repository.update { snapshot in
            guard let index = snapshot.sessions.firstIndex(where: { $0.id == sessionID && $0.ownerID == ownerID }) else { throw ParkingError.sessionNotFound }
            guard snapshot.sessions[index].isActive(at: now) else { throw ParkingError.sessionEnded }
            snapshot.sessions[index].end = now
            return snapshot.sessions[index].reminderNotificationID
        }
        if let reminderID {
            try? await notifications.delete(id: reminderID)
        }
    }

    public func summary() async -> DomainSummary {
        guard let active = try? await activeSessions() else {
            return DomainSummary(title: "Parking", detail: "Unavailable")
        }
        guard let first = active.first else {
            return DomainSummary(title: "Parking", detail: "Not parked")
        }
        let minutes = Int(first.end.timeIntervalSince(dates.now) / 60)
        return DomainSummary(title: "Parking", detail: "\(first.plate) at \(first.zoneName), \(minutes) min left")
    }

    private func own() async throws -> [ParkingSession] {
        let ownerID = try await identity.currentUser().id
        return try await repository.load().sessions.filter { $0.ownerID == ownerID }
    }

    private static func available(_ zone: ParkingZone, in snapshot: ParkingSnapshot, at date: Date) -> Int {
        max(0, zone.totalSpots - snapshot.sessions.count { $0.zoneID == zone.id && $0.isActive(at: date) })
    }

    /// Returns nil when the reminder could not be scheduled. The session still stands.
    private func scheduleReminder(zoneName: String, plate: String, end: Date) async -> String? {
        let deliverAt = end.addingTimeInterval(-Self.reminderLead)
        guard deliverAt > dates.now else { return nil }
        return try? await notifications.post(NotificationDraft(
            title: "Parking ends in 10 minutes",
            body: "\(plate) at \(zoneName) expires at \(end.formatted(date: .omitted, time: .shortened)). Extend from the Parking screen.",
            category: .reminder,
            sourceDomain: "Parking",
            deliverAt: deliverAt
        )).id
    }
}
