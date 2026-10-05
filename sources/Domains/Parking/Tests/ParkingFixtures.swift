import CoreKit
import CoreModels
import Foundation
import IdentityAPI
import NotificationsAPI
@testable import Parking
import ParkingAPI
import WalletAPI

final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_791_201_600)
    var provider: DateProvider { DateProvider { self.now } }
}

enum ParkingFixtures {
    static let zone = ParkingZone(id: "z1", name: "Riverside", location: GeoPoint(latitude: 0, longitude: 0), hourlyRate: .usd(3), maxHours: 4, totalSpots: 2, rules: "")
    static let tiny = ParkingZone(id: "z2", name: "Alley", location: GeoPoint(latitude: 0, longitude: 0), hourlyRate: .usd(5), maxHours: 1, totalSpots: 1, rules: "")
    static let car = Vehicle(plate: "CIV 4821", nickname: "Car", ownerID: "user-1")
    static let van = Vehicle(plate: "RVR 1190", nickname: "Van", ownerID: "user-1")

    static func repository(sessions: [ParkingSession] = []) -> InMemoryParkingRepository {
        InMemoryParkingRepository(snapshot: ParkingSnapshot(zones: [zone, tiny], vehicles: [car, van], sessions: sessions))
    }

    struct Dependencies {
        let clock = TestClock()
        let wallet = RecordingWalletService()
        let notifications = RecordingNotificationsService()
    }

    static func service(_ repository: InMemoryParkingRepository, _ dependencies: Dependencies) -> LiveParkingService {
        LiveParkingService(repository: repository, identity: StubIdentityService(), wallet: dependencies.wallet,
                           notifications: dependencies.notifications, dates: dependencies.clock.provider, makeID: { "1" })
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(id: "user-1", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
                    address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: .distantPast)
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }
    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "") }
}

actor RecordingWalletService: WalletService {
    private(set) var payments: [PaymentRequest] = []
    var declines = false

    func decline() { declines = true }

    func balance() async throws -> Money { .usd(100) }
    func paymentMethods() async throws -> [PaymentMethod] { [] }
    func transactions() async throws -> [WalletTransaction] { [] }

    func pay(_ request: PaymentRequest, methodID: String?) async throws -> PaymentReceipt {
        if declines { throw WalletError.insufficientFunds(available: .zero) }
        payments.append(request)
        return PaymentReceipt(transactionID: "tx-\(payments.count)", merchant: request.merchant, amount: request.amount, date: .distantPast,
                              paymentMethod: PaymentMethod(id: "pm", kind: .cityCard, label: "City", last4: "0042", isDefault: true),
                              payerName: "Sam Lee", remainingBalance: .zero)
    }

    func topUp(_ amount: Money, fromMethodID methodID: String) async throws -> Money { amount }
    func summary() async -> DomainSummary { DomainSummary(title: "Wallet", detail: "") }
}

actor RecordingNotificationsService: NotificationsService {
    private(set) var posted: [NotificationDraft] = []
    private(set) var deleted: [String] = []

    func inbox() async throws -> [CityNotification] { [] }
    func unreadCount() async throws -> Int { 0 }
    func markRead(id: String) async throws {}
    func markAllRead() async throws {}

    func delete(id: String) async throws {
        deleted.append(id)
    }

    func post(_ draft: NotificationDraft) async throws -> CityNotification {
        posted.append(draft)
        return CityNotification(id: "reminder-\(posted.count)", recipientID: "user-1", title: draft.title, body: draft.body,
                                date: draft.deliverAt ?? .distantPast, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}
