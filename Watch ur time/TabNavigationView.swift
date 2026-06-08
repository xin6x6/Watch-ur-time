//
//  TabView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct TabNavigationView: View {
    @State private var tabSelection: Int = 0
    
    var body: some View {
        TabView {
            TimeTableView().tabItem{ Label("Timetable", systemImage: "calendar.badge.clock") }
            
            
        }
    }
}

#Preview {
    TabNavigationView()
}
