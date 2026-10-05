import CoreKit
import DI
import Identity
import Notifications
import Places
import SwiftUI

public enum ReportIssueFeature {
    public static func register(in container: Container) {
        container.registerShared((any ReportIssueService).self) {
            LiveReportIssueService(
                repository: BundleReportsRepository(loader: MockDataLoader()),
                identity: container.resolve((any IdentityService).self),
                places: container.resolve((any PlacesService).self),
                notifications: container.resolve((any NotificationsService).self)
            )
        }
        container.register(ReportIssueEntryPoints.self) {
            ReportIssueEntryPoints { AnyView(NewReportScreen(service: container.resolve((any ReportIssueService).self))) }
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ReportsScreen(service: container.resolve((any ReportIssueService).self), places: container.resolve(PlacesEntryPoints.self))
    }
}
