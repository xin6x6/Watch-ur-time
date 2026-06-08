//
//  ContentView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct TimeTableView: View {
    @Binding var day: Int
    
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
                    
                    DayView(selectedDay: day)
                }
            }
        }
        .padding()
    }
}

struct DayView: View {
    var selectedDay: Int

    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(140)),
                GridItem(.flexible())
            ],
            spacing: 4
        ) {
            tableCell("Time", isHeader: true)
            tableCell("Lesson", isHeader: true)
            
            tableCell("09:00 - 9:40")
                .redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .red).redacted(reason: .placeholder)
            
            tableCell("09:00 - 9:40").redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .green).redacted(reason: .placeholder)
            
            tableCell("09:00 - 9:40").redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .blue).redacted(reason: .placeholder)
            
            tableCell("09:00 - 9:40").redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .cyan).redacted(reason: .placeholder)
            
            tableCell("09:00 - 9:40").redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .purple).redacted(reason: .placeholder)
            
            tableCell("09:00 - 9:40").redacted(reason: .placeholder)
            tableCell("lesson", strokeColor: .indigo).redacted(reason: .placeholder)
        }
    }
    
    func tableCell(_ text: String, isHeader: Bool = false, strokeColor: Color = .gray) -> some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .stroke(strokeColor.opacity(0.4), lineWidth: 2)
            Text(text)
                .font(isHeader ? .headline : .body)
                .frame(maxWidth: .infinity, minHeight: 50)
        }

    }
}

#Preview {
    TimeTableView(day: .constant(1))
}
