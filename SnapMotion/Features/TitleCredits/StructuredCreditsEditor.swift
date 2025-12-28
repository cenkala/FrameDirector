//
//  StructuredCreditsEditor.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct StructuredCreditsEditor: View {
    @Binding var credits: StructuredCredits
    
    var body: some View {
        VStack(spacing: 12) {
            CreditsField(
                label: LocalizedStringKey("titleCredits.director"),
                text: $credits.director
            )
            
            CreditsField(
                label: LocalizedStringKey("titleCredits.animator"),
                text: $credits.animator
            )
            
            CreditsField(
                label: LocalizedStringKey("titleCredits.music"),
                text: $credits.music
            )
            
            CreditsField(
                label: LocalizedStringKey("titleCredits.thanks"),
                text: $credits.thanks
            )
        }
    }
}

struct CreditsField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundStyle(.secondary)
            
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

