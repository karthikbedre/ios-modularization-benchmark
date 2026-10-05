import Foundation
@testable import Notifications
import NotificationsAPI
import Testing

struct InboxSectionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let delivered = Array(NotificationsFixtures.notifications.prefix(3))

    @Test func bucketsIntoTodayThisWeekAndEarlier() {
        let sections = InboxSection.make(delivered, filter: .all, now: NotificationsFixtures.now, calendar: calendar)

        #expect(sections.map(\.period) == [.today, .thisWeek, .earlier])
        #expect(sections.map { $0.notifications.map(\.id) } == [["today"], ["week"], ["old"]])
    }

    @Test(arguments: [
        (InboxFilter.unread, ["today", "old"]),
        (InboxFilter.category(.booking), ["week"]),
        (InboxFilter.category(.cityAlert), []),
    ])
    func filtersBeforeBucketing(filter: InboxFilter, expected: [String]) {
        let sections = InboxSection.make(delivered, filter: filter, now: NotificationsFixtures.now, calendar: calendar)

        #expect(sections.flatMap { $0.notifications.map(\.id) } == expected)
    }
}

@MainActor
struct InboxViewModelTests {
    @Test func openingMarksReadAndReloads() async {
        let viewModel = InboxViewModel(service: NotificationsFixtures.service(repository: NotificationsFixtures.repository()), dates: .fixed(NotificationsFixtures.now))
        await viewModel.load()
        #expect(viewModel.unreadCount == 2)

        await viewModel.open(viewModel.state.value![0])

        #expect(viewModel.unreadCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func deleteRemovesFromInbox() async {
        let viewModel = InboxViewModel(service: NotificationsFixtures.service(repository: NotificationsFixtures.repository()), dates: .fixed(NotificationsFixtures.now))
        await viewModel.load()

        await viewModel.delete(viewModel.state.value![1])

        #expect(viewModel.state.value?.map(\.id) == ["today", "old"])
    }
}
