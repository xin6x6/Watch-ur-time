//
//  Time_on_ur_watchApp.swift
//  Time on ur watch Watch App
//
//  Created by Ng1nx on 6/22/26.
//

import SwiftUI

@main
struct Time_on_ur_watch_Watch_AppApp: App {
    @StateObject private var dataStore = WatchDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environment(\.watchAppFontOption, dataStore.appFontOption)
                .watchAppDefaultFont()
        }
    }
}
