#if DEBUG
import CoreModels
import Foundation

extension TransitLine {
    public static let preview = TransitLine(id: "line-2", name: "Line 2", mode: .metro, colorHex: "#E4572E", stopIDs: ["stop-central", "stop-harbor"],
                                            firstDeparture: 300, lastDeparture: 1440, headwayMinutes: 6, minutesBetweenStops: 3)
}

extension TransitStop {
    public static let preview = TransitStop(id: "stop-central", name: "Central Station", location: GeoPoint(latitude: 40.7139, longitude: -74.0042))
}

public struct PreviewTransitService: TransitService {
    public init() {}

    public func lines() async throws -> [TransitLine] { [.preview] }
    public func stops() async throws -> [TransitStop] { [.preview] }
    public func stop(id: String) async throws -> TransitStop { .preview }

    public func departures(stopID: String, limit: Int) async throws -> [Departure] {
        (1...limit).map { Departure(line: .preview, stopID: stopID, time: .now.addingTimeInterval(Double($0) * 360), destination: "Harbor Station") }
    }

    public func planTrip(fromStopID: String, toStopID: String) async throws -> Trip {
        Trip(legs: [TripLeg(line: .preview, from: .preview, to: .preview, departure: .now.addingTimeInterval(240), arrival: .now.addingTimeInterval(840), stopCount: 3)])
    }

    public func passOptions() async throws -> [PassOption] { [PassOption(kind: .day, price: .usd(7))] }
    public func passes() async throws -> [TransitPass] { [] }

    public func buyPass(_ kind: PassKind) async throws -> TransitPass {
        TransitPass(id: "p", ownerID: "user-preview", kind: kind, validFrom: .now, validUntil: .now.addingTimeInterval(kind.validity), price: .usd(7), transactionID: "tx")
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Transit", detail: "Line 2 in 4 min")
    }
}
#endif
