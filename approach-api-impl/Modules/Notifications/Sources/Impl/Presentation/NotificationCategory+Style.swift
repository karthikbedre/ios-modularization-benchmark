import DesignSystem
import NotificationsAPI
import SwiftUI

extension NotificationCategory {
    var systemImage: String {
        switch self {
        case .payment: "creditcard.fill"
        case .booking: "calendar.badge.checkmark"
        case .reminder: "bell.badge.fill"
        case .cityAlert: "exclamationmark.triangle.fill"
        case .library: "books.vertical.fill"
        case .report: "wrench.and.screwdriver.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cityAlert: Palette.warning
        case .payment: Palette.positive
        default: Palette.accent
        }
    }
}
