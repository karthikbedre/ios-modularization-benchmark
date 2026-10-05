import CoreModels
import Foundation
@testable import Parking
import Parking
import Testing

private typealias F = ParkingFixtures

struct PlateValidatorTests {
    @Test(arguments: [("civ  4821", "CIV 4821"), (" ab1 ", "AB1"), ("XYZ12345", "XYZ12345")])
    func normalizesValidPlates(input: String, expected: String) throws {
        #expect(try PlateValidator.normalize(input) == expected)
    }

    @Test(arguments: ["A", "TOOLONG123", "AB-12", "A B C", "ÄBC 12"])
    func rejectsInvalidPlates(input: String) {
        #expect(throws: ParkingError.invalidPlate) { try PlateValidator.normalize(input) }
    }
}

struct LiveParkingServiceTests {
    private let repository = F.repository()
    private let dependencies = F.Dependencies()
    private var service: LiveParkingService { F.service(repository, dependencies) }

    @Test func startPaysClaimsSpotAndSchedulesReminder() async throws {
        let session = try await service.start(zoneID: "z1", plate: "CIV 4821", hours: 2)

        #expect(session.cost == .usd(6))
        #expect(session.end == dependencies.clock.now.addingTimeInterval(7200))
        #expect(session.transactionIDs == ["tx-1"])
        #expect(session.reminderNotificationID == "reminder-1")
        #expect(await dependencies.wallet.payments.map(\.category) == [.parking])
        #expect(await dependencies.notifications.posted.first?.deliverAt == session.end.addingTimeInterval(-600))
        #expect(try await service.zones().first { $0.id == "z1" }?.availableSpots == 1)
    }

    @Test func declinedPaymentReleasesTheSpot() async {
        await dependencies.wallet.decline()

        await #expect(throws: (any Error).self) { try await service.start(zoneID: "z1", plate: "CIV 4821", hours: 1) }

        #expect(await repository.snapshot.sessions.isEmpty)
        #expect(await dependencies.notifications.posted.isEmpty)
    }

    @Test func fullZoneAndDoubleParkingAreRejected() async throws {
        _ = try await service.start(zoneID: "z2", plate: "CIV 4821", hours: 1)

        await #expect(throws: ParkingError.zoneFull) { try await service.start(zoneID: "z2", plate: "RVR 1190", hours: 1) }
        await #expect(throws: ParkingError.vehicleAlreadyParked) { try await service.start(zoneID: "z1", plate: "CIV 4821", hours: 1) }
        #expect(await dependencies.wallet.payments.count == 1)
    }

    @Test(arguments: [0, 5])
    func hoursAreBoundedByZone(hours: Int) async {
        await #expect(throws: ParkingError.hoursOutOfRange(max: 4)) { try await service.quote(zoneID: "z1", hours: hours) }
    }

    @Test func extendPaysReplacesReminderAndRespectsLimit() async throws {
        let session = try await service.start(zoneID: "z1", plate: "CIV 4821", hours: 2)

        let extended = try await service.extend(sessionID: session.id, by: 1)

        #expect(extended.end == session.end.addingTimeInterval(3600))
        #expect(extended.cost == .usd(9))
        #expect(extended.transactionIDs == ["tx-1", "tx-2"])
        #expect(await dependencies.notifications.deleted == ["reminder-1"])
        #expect(extended.reminderNotificationID == "reminder-2")
        await #expect(throws: ParkingError.hoursOutOfRange(max: 1)) { try await service.extend(sessionID: session.id, by: 2) }
    }

    @Test func endingEarlyMovesToHistoryAndCancelsReminder() async throws {
        let session = try await service.start(zoneID: "z1", plate: "CIV 4821", hours: 2)
        dependencies.clock.now = dependencies.clock.now.addingTimeInterval(1800)

        try await service.end(sessionID: session.id)

        #expect(try await service.activeSessions().isEmpty)
        #expect(try await service.history().first?.end == dependencies.clock.now)
        #expect(await dependencies.notifications.deleted == ["reminder-1"])
        await #expect(throws: ParkingError.sessionEnded) { try await service.end(sessionID: session.id) }
    }

    @Test func spotsFreeUpWhenSessionsExpire() async throws {
        let session = try await service.start(zoneID: "z2", plate: "CIV 4821", hours: 1)
        #expect(try await service.zones().first { $0.id == "z2" }?.isFull == true)

        dependencies.clock.now = session.end

        #expect(try await service.zones().first { $0.id == "z2" }?.availableSpots == 1)
        #expect(try await service.history().map(\.id) == [session.id])
    }

    @Test func vehiclesAreNormalizedAndDeduplicated() async throws {
        let added = try await service.addVehicle(plate: "new  1", nickname: "  ")

        #expect(added == Vehicle(plate: "NEW 1", nickname: "NEW 1", ownerID: "user-1"))
        await #expect(throws: ParkingError.duplicateVehicle) { try await service.addVehicle(plate: "civ 4821", nickname: "") }
        try await service.removeVehicle(plate: "NEW 1")
        #expect(try await service.vehicles().map(\.plate) == ["CIV 4821", "RVR 1190"])
    }
}

@MainActor
struct ParkingViewModelTests {
    @Test func loadsAndSurfacesExtendErrors() async throws {
        let dependencies = F.Dependencies()
        let service = F.service(F.repository(), dependencies)
        let session = try await service.start(zoneID: "z2", plate: "CIV 4821", hours: 1)
        let viewModel = ParkingViewModel(service: service)

        await viewModel.load()
        #expect(viewModel.state.value?.active.map(\.id) == [session.id])

        await viewModel.extend(session, by: 1)

        #expect(viewModel.errorMessage == "This session is already at the zone's time limit.")
    }

    @Test func walletFailureHasAFriendlyMessage() {
        #expect(ParkingMessages.message(for: CancellationError()) == "The payment did not go through. Check your wallet and try again.")
    }
}
