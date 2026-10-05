#if DEBUG
import CoreModels
import Foundation

extension ParkingZone {
    public static let preview = ParkingZone(
        id: "zone-r4", name: "Riverside Garage R4", location: GeoPoint(latitude: 40.7198, longitude: -74.0089),
        hourlyRate: .usd(3), maxHours: 4, totalSpots: 120, rules: "Mon to Sat 8 AM to 8 PM"
    )
}

public struct PreviewParkingService: ParkingService {
    public init() {}

    private static let session = ParkingSession(
        id: "s1", ownerID: "user-preview", zoneID: "zone-r4", zoneName: "Riverside Garage R4", plate: "CIV 4821",
        start: .now.addingTimeInterval(-1800), end: .now.addingTimeInterval(3600), cost: .usd(4.50), transactionIDs: ["tx"]
    )

    public func zones() async throws -> [ZoneAvailability] { [ZoneAvailability(zone: .preview, availableSpots: 14)] }
    public func vehicles() async throws -> [Vehicle] { [Vehicle(plate: "CIV 4821", nickname: "Blue hatchback", ownerID: "user-preview")] }
    public func addVehicle(plate: String, nickname: String) async throws -> Vehicle { Vehicle(plate: plate, nickname: nickname, ownerID: "user-preview") }
    public func removeVehicle(plate: String) async throws {}
    public func activeSessions() async throws -> [ParkingSession] { [Self.session] }
    public func history() async throws -> [ParkingSession] { [] }

    public func quote(zoneID: String, hours: Int) async throws -> ParkingQuote {
        ParkingQuote(zoneID: zoneID, hours: hours, cost: .usd(3) * hours, end: .now.addingTimeInterval(Double(hours) * 3600))
    }

    public func start(zoneID: String, plate: String, hours: Int) async throws -> ParkingSession { Self.session }
    public func extend(sessionID: String, by hours: Int) async throws -> ParkingSession { Self.session }
    public func end(sessionID: String) async throws {}

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Parking", detail: "CIV 4821 parked, 1 hour left")
    }
}
#endif
