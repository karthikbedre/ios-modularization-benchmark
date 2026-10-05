@testable import Agenda
import AgendaAPI
import Foundation
import Testing

struct LiveAgendaServiceTests {
    private let repository = InMemoryAgendaRepository(entries: AgendaFixtures.entries)

    @Test func upcomingSkipsEndedAndOtherResidentsEntries() async throws {
        let service = AgendaFixtures.service(repository: repository)

        #expect(try await service.upcoming(limit: 10).map(\.id) == ["soon", "tomorrow", "next-week"])
        #expect(try await service.upcoming(limit: 1).map(\.id) == ["soon"])
    }

    @Test func entriesInIntervalIncludeOverlaps() async throws {
        let service = AgendaFixtures.service(repository: repository)
        let interval = DateInterval(start: AgendaFixtures.now.addingTimeInterval(2.5 * 3600), duration: 24 * 3600)

        #expect(try await service.entries(in: interval).map(\.id) == ["soon", "tomorrow"])
    }

    @Test func addSchedulesReminderBeforeStart() async throws {
        let notifications = RecordingNotificationsService()
        let service = AgendaFixtures.service(repository: repository, notifications: notifications)
        let start = AgendaFixtures.now.addingTimeInterval(5 * 3600)

        let entry = try await service.add(CalendarDraft(title: " Jazz ", start: start, end: start.addingTimeInterval(7200), location: "Harbor", sourceDomain: "Tickets", reminder: .oneHour))

        #expect(entry.title == "Jazz")
        let posted = await notifications.posted
        #expect(posted.count == 1)
        #expect(posted.first?.deliverAt == start.addingTimeInterval(-3600))
        #expect(posted.first?.category == .reminder)
    }

    @Test func reminderInThePastIsSkipped() async throws {
        let notifications = RecordingNotificationsService()
        let service = AgendaFixtures.service(repository: repository, notifications: notifications)
        let start = AgendaFixtures.now.addingTimeInterval(30 * 60)

        try await service.add(CalendarDraft(title: "Soon", start: start, end: start.addingTimeInterval(600), sourceDomain: "Agenda", reminder: .oneHour))

        #expect(await notifications.posted.isEmpty)
    }

    @Test(arguments: [
        (CalendarDraft(title: " ", start: AgendaFixtures.now, end: AgendaFixtures.now.addingTimeInterval(60), sourceDomain: "Agenda"), AgendaError.emptyTitle),
        (CalendarDraft(title: "Bad", start: AgendaFixtures.now, end: AgendaFixtures.now, sourceDomain: "Agenda"), AgendaError.endsBeforeStart),
        (CalendarDraft(title: "Dup", start: AgendaFixtures.now, end: AgendaFixtures.now.addingTimeInterval(60), sourceDomain: "Test", sourceItemID: "ticket-1"), AgendaError.alreadyAdded),
    ])
    func addRejectsInvalidDrafts(draft: CalendarDraft, expected: AgendaError) async {
        let service = AgendaFixtures.service(repository: repository)

        await #expect(throws: expected) { try await service.add(draft) }
        #expect(await repository.entries.count == AgendaFixtures.entries.count)
    }

    @Test func findsEntryBySource() async throws {
        let service = AgendaFixtures.service(repository: repository)

        #expect(try await service.entry(sourceDomain: "Test", sourceItemID: "ticket-1")?.id == "tomorrow")
        #expect(try await service.entry(sourceDomain: "Other", sourceItemID: "ticket-1") == nil)
    }

    @Test func removeRejectsAnotherResidentsEntry() async {
        let service = AgendaFixtures.service(repository: repository)

        await #expect(throws: AgendaError.notFound) { try await service.remove(id: "other-user") }
    }
}

struct AgendaDayTests {
    @Test func weekHasSevenDaysIncludingEmptyOnes() {
        let days = AgendaDay.week(starting: AgendaFixtures.now, entries: AgendaFixtures.entries, calendar: AgendaFixtures.utc)

        #expect(days.count == 7)
        #expect(days.map { $0.entries.map(\.id) }[0...2] == [["soon", "other-user"], ["tomorrow"], []])
    }

    @Test func multiDayEntryAppearsOnEachDay() {
        let longEntry = AgendaFixtures.entry("festival", startsInHours: 1, durationHours: 30)

        let days = AgendaDay.week(starting: AgendaFixtures.now, entries: [longEntry], calendar: AgendaFixtures.utc)

        #expect(days.prefix(3).map { $0.entries.count } == [1, 1, 0])
    }
}

@MainActor
struct AgendaViewModelTests {
    @Test func loadsWeekAndMovesForward() async {
        let viewModel = AgendaViewModel(
            service: AgendaFixtures.service(repository: InMemoryAgendaRepository(entries: AgendaFixtures.entries)),
            dates: .fixed(AgendaFixtures.now),
            calendar: AgendaFixtures.utc
        )

        await viewModel.load()
        #expect(viewModel.state.value?.flatMap { $0.entries.map(\.id) } == ["soon", "tomorrow"])

        await viewModel.moveWeek(by: 1)
        #expect(viewModel.state.value?.flatMap { $0.entries.map(\.id) } == ["next-week"])
    }
}
