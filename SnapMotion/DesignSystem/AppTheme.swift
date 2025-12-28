//
//  AppTheme.swift
//  Frame Director
//
//  Created by Cenk Alasonyalılar on 28.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(uiColor: .systemBackground)
        static let surface = Color(uiColor: .secondarySystemBackground)
        static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
        static let separator = Color(uiColor: .separator)

        static let accent = Color.accentColor
        static let destructive = Color(uiColor: .systemRed)

        static let chipBackground = Color(uiColor: .quaternarySystemFill)
        static let chipBorder = Color(uiColor: .tertiaryLabel).opacity(0.25)
    }

    enum Metrics {
        static let screenPadding: CGFloat = 16
        static let contentSpacing: CGFloat = 14
        static let cardCornerRadius: CGFloat = 18
        static let controlCornerRadius: CGFloat = 14
        static let chipCornerRadius: CGFloat = 999
    }

    enum Shadows {
        static let card = AppShadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct AppShadow: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct AppCardStyle: ViewModifier {
    var isElevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Metrics.screenPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(isElevated ? AppTheme.Colors.surface : AppTheme.Colors.elevatedSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
            }
            .shadow(
                color: AppTheme.Shadows.card.color,
                radius: AppTheme.Shadows.card.radius,
                x: AppTheme.Shadows.card.x,
                y: AppTheme.Shadows.card.y
            )
    }
}

struct AppScreenBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.Colors.background)
    }
}

extension View {
    func appCard(isElevated: Bool = true) -> some View {
        modifier(AppCardStyle(isElevated: isElevated))
    }

    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundStyle())
    }
}


