import CoreModels
import Foundation
import SwiftUI

public protocol ParkingService: SummaryProviding {
    func zones() async throws -> [ZoneAvailability]
    func vehicles() async throws -> [Vehicle]
    func addVehicle(plate: String, nickname: String) async throws -> Vehicle
    func removeVehicle(plate: String) async throws
    func activeSessions() async throws -> [ParkingSession]
    func history() async throws -> [ParkingSession]
    func quote(zoneID: String, hours: Int) async throws -> ParkingQuote
    /// Pays with the default wallet method, starts the session and schedules an expiry reminder.
    func start(zoneID: String, plate: String, hours: Int) async throws -> ParkingSession
    func extend(sessionID: String, by hours: Int) async throws -> ParkingSession
    /// Ends a session early. Unused time is not refunded.
    func end(sessionID: String) async throws
}

public struct ParkingEntryPoints: Sendable {
    public var parking: @MainActor @Sendable () -> AnyView

    public init(parking: @escaping @MainActor @Sendable () -> AnyView) {
        self.parking = parking
    }
}
