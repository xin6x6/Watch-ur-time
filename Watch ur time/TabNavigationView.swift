//
//  TabView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI

enum AppTab: Int, Hashable, CaseIterable {
    case timetable
    case notification
    case assignments
    case settings

    var title: String {
        switch self {
        case .timetable:
            return "Timetable"
        case .notification:
            return "Notification"
        case .assignments:
            return "Assignments"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .timetable:
            return "calendar.badge.clock"
        case .notification:
            return "bell.fill"
        case .assignments:
            return "book.closed.fill"
        case .settings:
            return "gear"
        }
    }
}

struct TabNavigationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var watchSyncManager: PhoneWatchSyncManager
    @EnvironmentObject private var classReminderScheduler: ClassReminderScheduler
    @Query(sort: \TimetableStore.updatedAt, order: .reverse) private var stores: [TimetableStore]
    @State private var tabSelection: AppTab = .timetable
    @State private var day: Int = Self.currentTimetableDay()
    
    var body: some View {
        TabView(selection: $tabSelection) {
            TimeTableView(day: $day)
                .tabItem { Label(AppTab.timetable.title, systemImage: AppTab.timetable.systemImage) }
                .tag(AppTab.timetable)
            
            NotificationView(day: $day)
                .tabItem { Label(AppTab.notification.title, systemImage: AppTab.notification.systemImage) }
                .tag(AppTab.notification)
            
            AssignmentsView(tabSelection: $tabSelection)
                .tabItem { Label(AppTab.assignments.title, systemImage: AppTab.assignments.systemImage) }
                .tag(AppTab.assignments)
            
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
        }
        .onAppear {
            syncDayWithCurrentWeekday()
            syncSharedOutputs()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                syncDayWithCurrentWeekday()
                syncSharedOutputs()
            }
        }
        .onChange(of: stores.first?.updatedAt) { _, _ in
            syncSharedOutputs()
        }
    }

    private func syncDayWithCurrentWeekday() {
        day = Self.currentTimetableDay()
    }

    private func syncSharedOutputs() {
        let snapshot = stores.first?.snapshot ?? .empty
        watchSyncManager.pushLatestSnapshotIfPossible()
        WidgetSnapshotStore.shared.update(with: snapshot)

        Task {
            await classReminderScheduler.sync(with: snapshot)
        }
    }

    private static func currentTimetableDay(for date: Date = Date()) -> Int {
        switch Calendar.current.component(.weekday, from: date) {
        case 2: return 1
        case 3: return 2
        case 4: return 3
        case 5: return 4
        case 6: return 5
        case 7, 1: return 1
        default: return 1
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: TimetableStore.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    TabNavigationView()
        .environmentObject(PhoneWatchSyncManager(modelContainer: container, activateSession: false))
        .environmentObject(ClassReminderScheduler())
        .modelContainer(container)
}
