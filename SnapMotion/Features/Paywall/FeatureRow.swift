//
//  FeatureRow.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
        }
    }
}

