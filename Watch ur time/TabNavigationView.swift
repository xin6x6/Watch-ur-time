//
//  TabView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct TabNavigationView: View {
    @State private var tabSelection: Int = 0
    @State var day: Int = 1
    
    var body: some View {
        TabView {
            TimeTableView(day: $day).tabItem{ Label("Timetable", systemImage: "calendar.badge.clock") }
            
            NotificationView(day: $day).tabItem { Label("Notification", systemImage: "bell.fill") }
            
            AssignmentsView().tabItem { Label("Assignments", systemImage: "book.closed.fill") }
            
            SettingsView().tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    TabNavigationView()
}
