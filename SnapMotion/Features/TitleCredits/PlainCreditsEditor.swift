//
//  PlainCreditsEditor.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct PlainCreditsEditor: View {
    @Binding var text: String
    
    var body: some View {
        TextField(
            LocalizedStringKey("titleCredits.plainPlaceholder"),
            text: $text,
            axis: .vertical
        )
        .lineLimit(5...15)
    }
}

