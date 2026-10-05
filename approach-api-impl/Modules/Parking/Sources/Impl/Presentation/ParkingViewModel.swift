import CoreKit
import Foundation
import Observation
import ParkingAPI

@MainActor
@Observable
final class ParkingViewModel {
    struct Content: Equatable {
        var active: [ParkingSession]
        var zones: [ZoneAvailability]
        var vehicles: [Vehicle]
    }

    private(set) var state: LoadState<Content> = .idle
    private(set) var errorMessage: String?

    let service: any ParkingService

    init(service: any ParkingService) {
        self.service = service
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let active = service.activeSessions()
            async let zones = service.zones()
            async let vehicles = service.vehicles()
            state = .loaded(Content(active: try await active, zones: try await zones, vehicles: try await vehicles))
        } catch {
            state = .failed("Parking could not be loaded.")
        }
    }

    func extend(_ session: ParkingSession, by hours: Int) async {
        await perform { _ = try await self.service.extend(sessionID: session.id, by: hours) }
    }

    func end(_ session: ParkingSession) async {
        await perform { try await self.service.end(sessionID: session.id) }
    }

    private func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = ParkingMessages.message(for: error)
        }
        await load()
    }
}

enum ParkingMessages {
    static func message(for error: any Error) -> String {
        switch error as? ParkingError {
        case .zoneNotFound: "This zone is not available."
        case .zoneFull: "This zone just filled up. Try a nearby one."
        case .invalidPlate: "Enter a plate with 2 to 8 letters or digits."
        case .duplicateVehicle: "That vehicle is already saved."
        case .unknownVehicle: "Add the vehicle before parking it."
        case .hoursOutOfRange(let max): max == 0 ? "This session is already at the zone's time limit." : "Choose between 1 and \(max) hours."
        case .vehicleAlreadyParked: "That vehicle already has an active session."
        case .sessionNotFound: "This session could not be found."
        case .sessionEnded: "This session has already ended."
        case nil: "The payment did not go through. Check your wallet and try again."
        }
    }
}
