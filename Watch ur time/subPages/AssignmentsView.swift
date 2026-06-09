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
    var body: some View {
        ZStack {
            // Lines
            HStack (spacing: 0) {
                
                // get View info
                GeometryReader { geo in
                    Path { path in
                        let spacing = geo.size.width / 8
                        
                        for i in 0..<9 {
                            let x = CGFloat(i) * spacing
                            
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                    }
                    .stroke(.gray.opacity(0.4), lineWidth: 2)
                }
            }
            
            // subjects
            VStack (spacing: 15) {
                ForEach(0 ..< 2) { i in
                    
                    //assignments per subject
                    VStack (spacing: 3) {
                        ForEach(0 ..< 3) { _ in
                            AssignmentBar(
                                subject: "Chinese",
                                assignment: "aaa",
                                color: .red,
                                width: 100,
                                height: 40,
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

#Preview {
    AssignmentsView()
}
