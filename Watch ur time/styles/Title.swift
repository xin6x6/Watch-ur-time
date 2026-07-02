//
//  Title.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct Title: View {
    var text: String;
    
    var body: some View {
        Text(text)
            .appFont(.headline, weight: .bold)
            .frame(
                maxWidth: .infinity,
                alignment: .top
            )
            
    }
}
