//
//  ContentView.swift
//  Time on ur watch Watch App
//
//  Created By Ng1nx on 6/22/26.
//

import SwiftUI

private enum WatchRootTab: Hashable {
    case timetable
    case assignments
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var dataStore: WatchDataStore
    @State private var selectedTab: WatchRootTab = .timetable

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                TimeTableView()
                    .tag(WatchRootTab.timetable)

                AssignmentsView()
                    .tag(WatchRootTab.assignments)
            }
            .tabViewStyle(.verticalPage)
        }
        .onAppear {
            dataStore.refreshCurrentDay()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dataStore.refreshCurrentDay()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataStore())
}
