import CoreKit
import CoreModels
import Foundation
import Identity
import Notifications
@testable import Wallet
import Wallet

enum WalletFixtures {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static let cityCard = PaymentMethod(id: "pm-city", kind: .cityCard, label: "City Card", last4: "0042", isDefault: true)
    static let debit = PaymentMethod(id: "pm-debit", kind: .debitCard, label: "Debit", last4: "7781", isDefault: false)

    static func transaction(_ id: String, _ merchant: String, _ category: TransactionCategory, cents: Int, hoursAgo: Double, reference: String? = nil) -> WalletTransaction {
        WalletTransaction(id: id, merchant: merchant, category: category, amount: Money(minorUnits: cents), date: now.addingTimeInterval(-hoursAgo * 3600), paymentMethodID: cityCard.id, reference: reference)
    }

    static let transactions = [
        transaction("t1", "Metro Line 2", .transit, cents: -275, hoursAgo: 1),
        transaction("t2", "Riverside Garage", .parking, cents: -900, hoursAgo: 30, reference: "Zone R4"),
        transaction("t3", "City Card top up", .topUp, cents: 4000, hoursAgo: 31),
        transaction("t4", "Noodle Bar 88", .dining, cents: -1845, hoursAgo: 55),
    ]

    static func snapshot(balanceCents: Int = 2000) -> WalletSnapshot {
        WalletSnapshot(balance: Money(minorUnits: balanceCents), paymentMethods: [debit, cityCard], transactions: transactions)
    }

    static func service(repository: InMemoryWalletRepository, notifications: RecordingNotificationsService = RecordingNotificationsService()) -> LiveWalletService {
        LiveWalletService(repository: repository, identity: StubIdentityService(), notifications: notifications, dates: .fixed(now), makeID: { "tx-new" })
    }
}

struct StubIdentityService: IdentityService {
    func currentUser() async throws -> UserProfile {
        UserProfile(
            id: "u", fullName: "Sam Lee", email: "sam@example.com", phone: "5550199", residentID: "CIV-1",
            address: Address(street: "1 Main", district: "Center", postalCode: "10000"), memberSince: WalletFixtures.now
        )
    }

    func update(_ update: ProfileUpdate) async throws -> UserProfile { try await currentUser() }

    func summary() async -> DomainSummary { DomainSummary(title: "Profile", detail: "Sam Lee") }
}

actor RecordingNotificationsService: NotificationsService {
    private(set) var posted: [NotificationDraft] = []

    func inbox() async throws -> [CityNotification] { [] }
    func unreadCount() async throws -> Int { 0 }
    func markRead(id: String) async throws {}
    func markAllRead() async throws {}
    func delete(id: String) async throws {}

    func post(_ draft: NotificationDraft) async throws -> CityNotification {
        posted.append(draft)
        return CityNotification(id: "n", recipientID: "u", title: draft.title, body: draft.body, date: WalletFixtures.now, category: draft.category, sourceDomain: draft.sourceDomain, isRead: false)
    }

    func preferences() async throws -> NotificationPreferences { NotificationPreferences() }
    func update(preferences: NotificationPreferences) async throws {}
    func summary() async -> DomainSummary { DomainSummary(title: "Inbox", detail: "") }
}
