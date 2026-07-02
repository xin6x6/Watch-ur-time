//
//  Watch_ur_timeApp.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftData
import SwiftUI

@main
struct Watch_ur_timeApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appDelegate
    @AppStorage("theme") private var theme: Themes = .System
    private let sharedModelContainer: ModelContainer
    @StateObject private var watchSyncManager: PhoneWatchSyncManager
    @StateObject private var classReminderScheduler = ClassReminderScheduler()

    init() {
        let container = try! ModelContainer(for: TimetableStore.self)
        self.sharedModelContainer = container
        _watchSyncManager = StateObject(
            wrappedValue: PhoneWatchSyncManager(modelContainer: container)
        )
        if let currentStore = try? container.mainContext.fetch(
            FetchDescriptor<TimetableStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).first {
            currentStore.notificationDeliveryMode.persistToDefaults()
            WidgetSnapshotStore.shared.update(with: currentStore.snapshot)
        } else {
            NotificationDeliveryMode.both.persistToDefaults()
            WidgetSnapshotStore.shared.update(with: .empty)
        }
    }

    var body: some Scene {
        WindowGroup {
            TabNavigationView()
                .environmentObject(watchSyncManager)
                .environmentObject(classReminderScheduler)
                .preferredColorScheme(preferredScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    private var preferredScheme: ColorScheme? {
        switch theme {
        case .Dark:
            return .dark
        case .Light:
            return .light
        case .System:
            return nil
        }
    }
}
