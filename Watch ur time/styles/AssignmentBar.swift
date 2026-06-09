//
//  AssignmentBar.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/9/26.
//

import SwiftUI

struct AssignmentBar: View {
    var subject: String
    var assignment: String
    var color: Color
    var width: CGFloat
    var height: CGFloat
    var x: CGFloat
//    var y: CGFloat
    var opacity: Double = 1
    @State var isFinished: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(color)
                .shadow(color: (isFinished ? .clear : color ), radius: 5)
            
                .opacity(opacity - (isFinished ? 0.5 : 0))
                .overlay{
                    if isFinished {
                        drawLine(
                            from: CGPoint(x: 0, y: height / 2),
                            to: CGPoint(x: x + width, y: height / 2),
                            color: .black,
                            width: 2
                        )
                    }
                }
                .frame(width: width, height: height)
                
            HStack{
                Text(subject + ":").bold(true)
                Text(assignment)
            }
        }
        .frame(width: width)
        .padding(.leading, x)
//        .position(x: x + width / 2, y: y + height / 2)
    }
}

func dayToPosition (day: Int, unit: CGFloat) -> CGFloat {
    return unit * CGFloat(day - 1)
}

#Preview {
    VStack(spacing: 3) {
        AssignmentBar(subject: "Chinese", assignment: "窘乏 死扽就烦扽江帆但凡扽扽江帆扽就翻翻就进进进进进进进",color: .blue, width: 300, height: 40, x: 0)
        AssignmentBar(
            subject: "Chinese",
            assignment: "aaa",
            color: .blue,
            width: 300,
            height: 40,
            x: 0,
            isFinished: true
        )
    }

}
