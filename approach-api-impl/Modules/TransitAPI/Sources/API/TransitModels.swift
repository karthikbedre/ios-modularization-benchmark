import CoreModels
import Foundation

public enum TransitMode: String, CaseIterable, Hashable, Sendable, Codable {
    case metro, tram, bus, ferry

    public var title: String { rawValue.capitalized }
}

public struct TransitLine: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var mode: TransitMode
    public var colorHex: String
    /// Stops in travel order from the first terminus to the last.
    public var stopIDs: [String]
    /// Minutes after midnight of the first and last departure from the first terminus.
    public var firstDeparture: Int
    public var lastDeparture: Int
    public var headwayMinutes: Int
    public var minutesBetweenStops: Int

    public init(id: String, name: String, mode: TransitMode, colorHex: String, stopIDs: [String], firstDeparture: Int, lastDeparture: Int, headwayMinutes: Int, minutesBetweenStops: Int) {
        self.id = id
        self.name = name
        self.mode = mode
        self.colorHex = colorHex
        self.stopIDs = stopIDs
        self.firstDeparture = firstDeparture
        self.lastDeparture = lastDeparture
        self.headwayMinutes = headwayMinutes
        self.minutesBetweenStops = minutesBetweenStops
    }
}

public struct TransitStop: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var location: GeoPoint

    public init(id: String, name: String, location: GeoPoint) {
        self.id = id
        self.name = name
        self.location = location
    }
}

public struct Departure: Identifiable, Hashable, Sendable {
    public var line: TransitLine
    public var stopID: String
    public var time: Date
    public var destination: String

    public init(line: TransitLine, stopID: String, time: Date, destination: String) {
        self.line = line
        self.stopID = stopID
        self.time = time
        self.destination = destination
    }

    public var id: String { "\(line.id)-\(destination)-\(time.timeIntervalSince1970)" }
}

public struct TripLeg: Hashable, Sendable {
    public var line: TransitLine
    public var from: TransitStop
    public var to: TransitStop
    public var departure: Date
    public var arrival: Date
    public var stopCount: Int

    public init(line: TransitLine, from: TransitStop, to: TransitStop, departure: Date, arrival: Date, stopCount: Int) {
        self.line = line
        self.from = from
        self.to = to
        self.departure = departure
        self.arrival = arrival
        self.stopCount = stopCount
    }
}

public struct Trip: Hashable, Sendable {
    public var legs: [TripLeg]

    public init(legs: [TripLeg]) {
        self.legs = legs
    }

    public var departure: Date? { legs.first?.departure }
    public var arrival: Date? { legs.last?.arrival }
    public var transfers: Int { max(0, legs.count - 1) }
}

public enum PassKind: String, CaseIterable, Hashable, Sendable, Codable {
    case single, day, week, month

    public var title: String {
        switch self {
        case .single: "Single ride"
        case .day: "Day pass"
        case .week: "7 day pass"
        case .month: "30 day pass"
        }
    }

    public var validity: TimeInterval {
        switch self {
        case .single: 90 * 60
        case .day: 24 * 3600
        case .week: 7 * 24 * 3600
        case .month: 30 * 24 * 3600
        }
    }
}

public struct PassOption: Hashable, Sendable, Codable {
    public var kind: PassKind
    public var price: Money

    public init(kind: PassKind, price: Money) {
        self.kind = kind
        self.price = price
    }
}

public struct TransitPass: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var ownerID: String
    public var kind: PassKind
    public var validFrom: Date
    public var validUntil: Date
    public var price: Money
    public var transactionID: String

    public init(id: String, ownerID: String, kind: PassKind, validFrom: Date, validUntil: Date, price: Money, transactionID: String) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.price = price
        self.transactionID = transactionID
    }

    public func isValid(at date: Date) -> Bool {
        validFrom <= date && validUntil > date
    }
}

public enum TransitError: Error, Hashable, Sendable {
    case stopNotFound
    case sameStop
    case noRoute
    case passStillValid(until: Date)
}
