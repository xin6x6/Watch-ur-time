//
//  ContentView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct TimeTableView: View {
    @State private var day: Int = 1
    
    var body: some View {
        VStack {
            Title(text: "Watch ur time")
            
            GlassCard{
                VStack {
                    Picker(selection: $day, label: Text("Select day")){
                        Text("Mon.").tag(1);
                        Text("Tue.").tag(2);
                        Text("Wed.").tag(3);
                        Text("Thu.").tag(4);
                        Text("Fri.").tag(5);
                    }.pickerStyle(SegmentedPickerStyle())
                        .padding(.bottom, 20)
                    
                    DayView()
                }
            }
        }
        .padding()
    }
}

struct DayView: View {
    var body: some View {
        Text("Hello, world!")
    }
}

#Preview {
    TimeTableView()
}
