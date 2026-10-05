import CoreModels
import SwiftUI

public protocol NotificationsService: SummaryProviding {
    /// Delivered notifications for the signed-in resident, newest first.
    func inbox() async throws -> [CityNotification]
    func unreadCount() async throws -> Int
    func markRead(id: String) async throws
    func markAllRead() async throws
    func delete(id: String) async throws
    @discardableResult
    func post(_ draft: NotificationDraft) async throws -> CityNotification
    func preferences() async throws -> NotificationPreferences
    func update(preferences: NotificationPreferences) async throws
}

/// Screens other domains can present without importing the Notifications implementation.
public struct NotificationsEntryPoints: Sendable {
    public var inbox: @MainActor @Sendable () -> AnyView

    public init(inbox: @escaping @MainActor @Sendable () -> AnyView) {
        self.inbox = inbox
    }
}
