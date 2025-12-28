//
//  StructuredCreditsEditor.swift
//  Frame Director
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
            
            if !credits.extras.isEmpty {
                Divider()
            }
            
            ForEach($credits.extras) { $extra in
                HStack(spacing: 10) {
                    TextField(
                        LocalizedStringKey("titleCredits.extraFieldLabel"),
                        text: $extra.label
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 86)
                    
                    TextField(
                        LocalizedStringKey("titleCredits.extraFieldValue"),
                        text: $extra.value,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    
                    Button(role: .destructive) {
                        credits.extras.removeAll { $0.id == extra.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                credits.extras.append(ExtraCreditField())
            } label: {
                Label(LocalizedStringKey("titleCredits.addExtraField"), systemImage: "plus.circle.fill")
            }
        }
    }
}

struct CreditsField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 87, alignment: .leading)
                .foregroundStyle(.secondary)
            
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

