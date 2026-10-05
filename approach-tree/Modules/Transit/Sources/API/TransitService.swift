import CoreModels
import Foundation
import SwiftUI

public protocol TransitService: SummaryProviding {
    func lines() async throws -> [TransitLine]
    func stops() async throws -> [TransitStop]
    func stop(id: String) async throws -> TransitStop
    func departures(stopID: String, limit: Int) async throws -> [Departure]
    /// The earliest arriving trip with at most one transfer.
    func planTrip(fromStopID: String, toStopID: String) async throws -> Trip
    func passOptions() async throws -> [PassOption]
    func passes() async throws -> [TransitPass]
    /// Buys with the default wallet method. Day and longer passes cannot overlap a valid pass of the same kind.
    func buyPass(_ kind: PassKind) async throws -> TransitPass
}

public struct TransitEntryPoints: Sendable {
    public var stop: @MainActor @Sendable (_ stopID: String) -> AnyView

    public init(stop: @escaping @MainActor @Sendable (_ stopID: String) -> AnyView) {
        self.stop = stop
    }
}
