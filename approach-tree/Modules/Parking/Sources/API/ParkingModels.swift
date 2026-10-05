import CoreModels
import Foundation

public struct ParkingZone: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var location: GeoPoint
    public var hourlyRate: Money
    public var maxHours: Int
    public var totalSpots: Int
    public var rules: String

    public init(id: String, name: String, location: GeoPoint, hourlyRate: Money, maxHours: Int, totalSpots: Int, rules: String) {
        self.id = id
        self.name = name
        self.location = location
        self.hourlyRate = hourlyRate
        self.maxHours = maxHours
        self.totalSpots = totalSpots
        self.rules = rules
    }
}

public struct ZoneAvailability: Identifiable, Hashable, Sendable {
    public var zone: ParkingZone
    public var availableSpots: Int

    public init(zone: ParkingZone, availableSpots: Int) {
        self.zone = zone
        self.availableSpots = availableSpots
    }

    public var id: String { zone.id }
    public var isFull: Bool { availableSpots == 0 }
}

public struct Vehicle: Identifiable, Hashable, Sendable, Codable {
    public var plate: String
    public var nickname: String
    public var ownerID: String

    public init(plate: String, nickname: String, ownerID: String) {
        self.plate = plate
        self.nickname = nickname
        self.ownerID = ownerID
    }

    public var id: String { plate }
}

public struct ParkingQuote: Hashable, Sendable {
    public var zoneID: String
    public var hours: Int
    public var cost: Money
    public var end: Date

    public init(zoneID: String, hours: Int, cost: Money, end: Date) {
        self.zoneID = zoneID
        self.hours = hours
        self.cost = cost
        self.end = end
    }
}

public struct ParkingSession: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var zoneID: String
    public var zoneName: String
    public var plate: String
    public var start: Date
    public var end: Date
    public var cost: Money
    public var transactionIDs: [String]
    public var reminderNotificationID: String?

    public init(id: String, ownerID: String, zoneID: String, zoneName: String, plate: String, start: Date, end: Date, cost: Money, transactionIDs: [String], reminderNotificationID: String? = nil) {
        self.id = id
        self.ownerID = ownerID
        self.zoneID = zoneID
        self.zoneName = zoneName
        self.plate = plate
        self.start = start
        self.end = end
        self.cost = cost
        self.transactionIDs = transactionIDs
        self.reminderNotificationID = reminderNotificationID
    }

    public func isActive(at date: Date) -> Bool {
        start <= date && end > date
    }
}

public enum ParkingError: Error, Hashable, Sendable {
    case zoneNotFound
    case zoneFull
    case invalidPlate
    case duplicateVehicle
    case unknownVehicle
    case hoursOutOfRange(max: Int)
    case vehicleAlreadyParked
    case sessionNotFound
    case sessionEnded
}
