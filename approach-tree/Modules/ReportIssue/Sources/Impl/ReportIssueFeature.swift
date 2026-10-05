import DI
import Map
import Notifications
import SwiftUI

public enum ReportIssueFeature {
    public static func register(in container: Container) {
        container.register((any ReportIssueService).self) {
            makeService(container)
        }
    }

    @MainActor
    public static func makeScreen(container: Container) -> some View {
        ReportIssueScreen(service: makeService(container))
    }

    private static func makeService(_ container: Container) -> LiveReportIssueService {
        LiveReportIssueService(map: container.resolve(), notifications: container.resolve())
    }
}
