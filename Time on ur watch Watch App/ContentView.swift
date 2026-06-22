//
//  ContentView.swift
//  Time on ur watch Watch App
//
//  Created by Ng1nx on 6/22/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            TabView {
                TimeTableView()
                AssignmentsView()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
