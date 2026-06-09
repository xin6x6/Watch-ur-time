//
//  AssignmentsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct AssignmentsView: View {
    @State var show: String = "All"
    
    var body: some View {
        VStack {
            Title(text: "Assignments")
            
            GlassCard {
                VStack {
                    HStack {
                        Picker ("Show: ", selection: $show) {
                            Text("All").tag(".all")
                            Text("Subject 1 Only").tag(".subject1")
                            Text("Subject 2 Only").tag(".subject2")
                            Text("Subject 3 Only").tag(".subject3")
                            Text("Subject 4 Only").tag(".subject4")
                        }
                        Spacer()
                        GlassButton(img: "chevron.left") {
                                // previous
                        }
                        GlassButton(img: "chevron.right") {
                                // later
                        }
                    }
                    
                    BarAssignmentsView()
                }
            }
        }.padding(.bottom)
    }
}

struct BarAssignmentsView: View {
    let days: [Date] = currentWeekDates()
    
    var body: some View {
        
        VStack {
            GeometryReader { geo in
                let spacing = geo.size.width / 6
                
                ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                    Text(formatDate(date))
                        .fontWidth(.compressed)
                        .position(x: CGFloat(index) * spacing, y: 10)
                }
            }.frame(height: 20)
            
            
            
            
            // get View info
            GeometryReader { geo in
                ZStack (alignment: .topLeading) {
                    let spacing = geo.size.width / 6
                    
                    
                        // Lines
                    HStack (spacing: 0) {
                        Path { path in
                            
                            for i in 0..<9 {
                                let x = CGFloat(i) * spacing
                                
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geo.size.height))
                            }
                        }
                        .stroke(.gray.opacity(0.4), lineWidth: 2)
                    }
                        

                        // subjects
                    VStack (alignment: .leading, spacing: 15) {
                        ForEach(0 ..< 2) { i in
                            
                                //assignments per subject
                            VStack (alignment: .leading, spacing: 3) {
                                ForEach(3 ..< 6) { j in
                                    AssignmentBar(
                                        subject: "Chinese",
                                        assignment: "aaa",
                                        color: .orange,
                                        width: dayToPosition(day: Int.random(in: 3..<7) , unit: spacing),
                                        height: 50,
                                        x: 0,
                                        isFinished: false
                                    )
                                }
                            }
                            
                            Divider()
                        }
                    }
                }
            }
        }

    }
}

//
func currentWeekDates() -> [Date] {
    let calendar = Calendar.current
    let today = Date()
    
    let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
    
    return (0..<7).compactMap { day in
        calendar.date(byAdding: .day, value: day, to: startOfWeek)
    }
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M.d"
    return formatter.string(from: date)
}

#Preview {
    AssignmentsView()
}
