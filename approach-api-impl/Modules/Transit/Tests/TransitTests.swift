import CoreKit
import CoreModels
import Foundation
import IdentityAPI
@testable import Transit
import TransitAPI
import WalletAPI
import Testing

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// Monday 2026-10-05 at `hour`:`minute` UTC, optionally on a later day.
private func at(_ hour: Int, _ minute: Int, day: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: 5 + day, hour: hour, minute: minute))!
}

private func stop(_ id: String) -> TransitStop {
    TransitStop(id: id, name: id.uppercased(), location: GeoPoint(latitude: 0, longitude: 0))
}

private let lineA = TransitLine(id: "a", name: "A", mode: .metro, colorHex: "#FF0000", stopIDs: ["s1", "s2", "s3"],
                                firstDeparture: 360, lastDeparture: 420, headwayMinutes: 30, minutesBetweenStops: 5)
private let lineB = TransitLine(id: "b", name: "B", mode: .bus, colorHex: "#00FF00", stopIDs: ["s3", "s4"],
                                firstDeparture: 360, lastDeparture: 1440, headwayMinutes: 10, minutesBetweenStops: 4)
private let stops = ["s1", "s2", "s3", "s4"].map(stop)
private let stopsByID = Dictionary(uniqueKeysWithValues: stops.map { ($0.id, $0) })

struct TimetableTests {
    @Test func runsLeaveInBothDirectionsAfterNow() {
        let runs = Timetable.runs(of: lineA, fromIndex: 1, after: at(6, 10), limit: 4, calendar: utc)

        #expect(Set(runs.prefix(2).map(\.towardIndex)) == [0, 2])
        #expect(runs.map(\.time) == [at(6, 35), at(6, 35), at(7, 5), at(7, 5)])
    }

    @Test func terminusOnlyRunsAwayFromItself() {
        let runs = Timetable.runs(of: lineA, fromIndex: 2, after: at(6, 10), limit: 5, calendar: utc)

        #expect(runs.allSatisfy { $0.towardIndex == 0 })
    }

    @Test func afterLastServiceTheNextRunIsTomorrow() {
        let next = Timetable.next(on: lineA, from: 1, to: 2, after: at(7, 5), calendar: utc)

        #expect(next?.departure == at(6, 5, day: 1))
        #expect(next?.arrival == at(6, 10, day: 1))
    }

    @Test func reverseTravelUsesTheOtherTerminusAsOrigin() {
        let next = Timetable.next(on: lineA, from: 2, to: 0, after: at(6, 10), calendar: utc)

        #expect(next?.departure == at(6, 30))
        #expect(next?.arrival == at(6, 40))
    }
}

struct TripPlannerTests {
    @Test func directTripWhenOneLineServesBothStops() throws {
        let trip = try #require(TripPlanner.plan(from: stopsByID["s1"]!, to: stopsByID["s3"]!, lines: [lineA, lineB], stops: stopsByID, after: at(6, 10), calendar: utc))

        #expect(trip.transfers == 0)
        #expect(trip.departure == at(6, 30))
        #expect(trip.arrival == at(6, 40))
    }

    @Test func oneTransferWithBuffer() throws {
        let trip = try #require(TripPlanner.plan(from: stopsByID["s1"]!, to: stopsByID["s4"]!, lines: [lineA, lineB], stops: stopsByID, after: at(6, 10), calendar: utc))

        #expect(trip.legs.map(\.line.id) == ["a", "b"])
        #expect(trip.legs[1].from.id == "s3")
        #expect(trip.legs[1].departure == at(6, 50))
        #expect(trip.arrival == at(6, 54))
    }

    @Test func noRouteWithoutSharedStops() {
        let island = TransitLine(id: "c", name: "C", mode: .ferry, colorHex: "#0000FF", stopIDs: ["x", "y"], firstDeparture: 360, lastDeparture: 1200, headwayMinutes: 30, minutesBetweenStops: 10)

        #expect(TripPlanner.plan(from: stopsByID["s1"]!, to: stop("y"), lines: [lineA, island], stops: stopsByID, after: at(6, 10), calendar: utc) == nil)
    }
}

private struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: .distantPast)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

private actor RecordingWalletService: WalletService {
    private(set) var payments: [PaymentRequest] = []

    func balance() async throws -> Money { .usd(100) }
    func paymentMethods() async throws -> [PaymentMethod] { [] }
    func transactions() async throws -> [WalletTransaction] { [] }

    func pay(_ request: PaymentRequest, methodID: String?) async throws -> PaymentReceipt {
        payments.append(request)
        return PaymentReceipt(transactionID: "tx-\(payments.count)", merchant: request.merchant, amount: request.amount, date: .distantPast,
                              paymentMethod: PaymentMethod(id: "pm", kind: .cityCard, label: "City", last4: "0042", isDefault: true),
                              payerName: "Sam Lee", remainingBalance: .zero)
    }

    func topUp(_ amount: Money, fromMethodID methodID: String) async throws -> Money { amount }
    func summary() async -> DomainSummary { DomainSummary(title: "Wallet", detail: "") }
}

struct LiveTransitServiceTests {
    private let wallet = RecordingWalletService()
    private let repository = InMemoryTransitRepository(snapshot: TransitSnapshot(
        stops: stops,
        lines: [lineA, lineB],
        passOptions: [PassOption(kind: .single, price: .usd(2.75)), PassOption(kind: .day, price: .usd(7))],
        passes: []
    ))
    private var service: LiveTransitService {
        LiveTransitService(repository: repository, identity: StubIdentityService(), wallet: wallet, dates: .fixed(at(6, 10)), calendar: utc, makeID: { "1" })
    }

    @Test func departuresMergeLinesAndNameDestinations() async throws {
        let departures = try await service.departures(stopID: "s3", limit: 3)

        #expect(departures.map(\.time) == [at(6, 20), at(6, 30), at(6, 30)])
        #expect(departures.first?.destination == "S4")
        #expect(Set(departures.dropFirst().map(\.destination)) == ["S1", "S4"])
    }

    @Test func invalidTripRequestsThrow() async {
        await #expect(throws: TransitError.sameStop) { try await service.planTrip(fromStopID: "s1", toStopID: "s1") }
        await #expect(throws: TransitError.stopNotFound) { try await service.planTrip(fromStopID: "s1", toStopID: "nope") }
        await #expect(throws: TransitError.stopNotFound) { try await service.departures(stopID: "nope", limit: 1) }
    }

    @Test func buyingADayPassPaysAndBlocksAnOverlappingOne() async throws {
        let pass = try await service.buyPass(.day)

        #expect(pass.validUntil == at(6, 10, day: 1))
        #expect(pass.transactionID == "tx-1")
        #expect(await wallet.payments.map(\.amount) == [.usd(7)])
        await #expect(throws: TransitError.passStillValid(until: at(6, 10, day: 1))) { try await service.buyPass(.day) }
    }

    @Test func singleRidesCanBeBoughtRepeatedly() async throws {
        _ = try await service.buyPass(.single)
        _ = try await service.buyPass(.single)

        #expect(try await service.passes().count == 2)
    }

    @Test func summaryPrefersAValidPass() async throws {
        _ = try await service.buyPass(.day)

        #expect(await service.summary().detail.hasPrefix("Day pass valid until"))
    }
}

struct TransitPresentationTests {
    @Test func lineColorParsesHex() {
        #expect(lineA.color == .init(red: 1, green: 0, blue: 0))
    }

    @Test func stopFavoriteListsItsLines() {
        #expect(stopsByID["s3"]!.favoriteDraft(lines: [lineA, lineB]).subtitle == "A, B")
    }
}
