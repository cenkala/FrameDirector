//
//  ProFeatureLockedView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct ProFeatureLockedView: View {
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundStyle(proGradient)
            
            Text(LocalizedStringKey("pro.locked"))
                .font(.title2.bold())
            
            Text(LocalizedStringKey("pro.unlockMessage"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                onUpgrade()
            } label: {
                Text(LocalizedStringKey("pro.upgrade"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding()
    }

    private var proGradient: LinearGradient {
        LinearGradient(
            colors: [Color(uiColor: .systemYellow), Color(uiColor: .systemOrange)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ProFeatureBadge: ViewModifier {
    let isLocked: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.controlCornerRadius, style: .continuous)
                        .strokeBorder(proGradient, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(proGradient)
                        )
                        .offset(x: 8, y: -8)
                }
            }
    }

    private var proGradient: LinearGradient {
        LinearGradient(
            colors: [Color(uiColor: .systemYellow), Color(uiColor: .systemOrange)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func proFeatureBadge(isLocked: Bool) -> some View {
        modifier(ProFeatureBadge(isLocked: isLocked))
    }
}

