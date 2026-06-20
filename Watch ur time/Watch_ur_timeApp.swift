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
    var body: some Scene {
        WindowGroup {
            TabNavigationView()
        }
        .modelContainer(for: [TimetableStore.self])
    }
}
