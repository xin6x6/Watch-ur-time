//
//  Line.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/9/26.
//

import SwiftUI

func drawLine(from: CGPoint, to: CGPoint, color: Color, width: CGFloat, opacity: Double = 1) -> some View {
    return Path { path in
        path.move(to: from)
        path.addLine(to: to)
    }
    .stroke(color, lineWidth: width)
    .opacity(opacity)
    .frame(width: max(width, abs(to.x - from.x)), alignment: .center)
}

#Preview {
    HStack {
        drawLine(from: CGPoint(x: 0, y:0), to: CGPoint(x: 0, y: 100), color: .gray, width: 2)
        drawLine(from: CGPoint(x: 0, y:0), to: CGPoint(x: 0, y: 100), color: .gray, width: 2)
    }
}
