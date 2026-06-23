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
    private let sharedModelContainer: ModelContainer
    @StateObject private var watchSyncManager: PhoneWatchSyncManager

    init() {
        let container = try! ModelContainer(for: TimetableStore.self)
        self.sharedModelContainer = container
        _watchSyncManager = StateObject(
            wrappedValue: PhoneWatchSyncManager(modelContainer: container)
        )
    }

    var body: some Scene {
        WindowGroup {
            TabNavigationView()
                .environmentObject(watchSyncManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
