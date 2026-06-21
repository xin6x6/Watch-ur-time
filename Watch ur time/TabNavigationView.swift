//
//  TabView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

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
    @State private var tabSelection: AppTab = .timetable
    @State var day: Int = 1
    
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
    }
}

#Preview {
    TabNavigationView()
}
