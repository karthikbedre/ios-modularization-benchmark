import DesignSystem
import SwiftUI

struct InboxScreen: View {
    @State private var viewModel: InboxViewModel
    @State private var showsSettings = false

    init(service: any NotificationsService) {
        _viewModel = State(initialValue: InboxViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { _ in
            let sections = viewModel.sections
            if sections.isEmpty {
                EmptyStateView("Nothing here", systemImage: "tray", message: "New messages from the city and your bookings show up here.")
            } else {
                List {
                    ForEach(sections) { section in
                        Section(section.period.title) {
                            ForEach(section.notifications) { notification in
                                NavigationLink(value: notification) {
                                    NotificationRow(notification: notification)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        Task { await viewModel.delete(notification) }
                                    }
                                }
                            }
                        }
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Inbox")
        .navigationDestination(for: CityNotification.self) { notification in
            NotificationDetailScreen(notification: notification)
                .task { await viewModel.open(notification) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Show", selection: $viewModel.filter) {
                        Text("All").tag(InboxFilter.all)
                        Text("Unread").tag(InboxFilter.unread)
                        ForEach(NotificationCategory.allCases, id: \.self) { category in
                            Label(category.title, systemImage: category.systemImage).tag(InboxFilter.category(category))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: viewModel.filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark all as read", systemImage: "envelope.open") {
                        Task { await viewModel.markAllRead() }
                    }
                    .disabled(viewModel.unreadCount == 0)
                    Button("Notification settings", systemImage: "gearshape") {
                        showsSettings = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                NotificationSettingsScreen(service: viewModel.service)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

struct NotificationRow: View {
    let notification: CityNotification

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Image(systemName: notification.category.systemImage)
                .foregroundStyle(notification.category.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    Spacer()
                    Text(notification.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !notification.isRead {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .accessibilityLabel("Unread")
            }
        }
    }
}

#Preview {
    NavigationStack {
        InboxScreen(service: PreviewNotificationsService())
    }
}
