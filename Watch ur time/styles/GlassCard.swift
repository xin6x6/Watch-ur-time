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
        
            .glassEffect(
                
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                
            )
        
            .padding(.horizontal)
    }
}
