//
//  AppComponents.swift
//  Frame Director
//
//  Created by Cenk Alasonyalılar on 28.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import SwiftUI

struct AppSectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppChip: View {
    let systemImage: String
    private let text: Text

    init(systemImage: String, text: String) {
        self.systemImage = systemImage
        self.text = Text(text)
    }

    init(systemImage: String, textKey: LocalizedStringKey) {
        self.systemImage = systemImage
        self.text = Text(textKey)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            text
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.Colors.chipBackground)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.Colors.chipBorder, lineWidth: 1)
        }
    }
}

struct AppIconBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.chipBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
            }
    }
}

extension View {
    func appFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
    }
}


