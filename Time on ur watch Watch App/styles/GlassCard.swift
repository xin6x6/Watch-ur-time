//
//  GlassCardView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//
import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .compatibleGlassSurface(cornerRadius: 30)
            .padding(.horizontal)
    }
}

extension View {
    @ViewBuilder
    func compatibleGlassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(watchOS 26.0, *) {
            if let tint {
                self
                    .background(tint.opacity(0.16), in: shape)
                    .glassEffect(in: shape)
            } else {
                self.glassEffect(in: shape)
            }
        } else {
            self
                .background {
                    shape.fill(.ultraThinMaterial)

                    if let tint {
                        shape.fill(tint.opacity(0.16))
                    }
                }
                .overlay {
                    shape.stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
    }
}
