//
//  ProjectCardView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import UIKit

struct ProjectCardView: View {
    let project: MovieProject
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRequestDeleteUpgrade: () -> Void
    let canDelete: Bool

    @State private var thumbnailImage: UIImage?

    private var hasPlayableVideo: Bool {
        if project.exportedVideoURL != nil {
            return true
        }

        let url = MovieStorage.exportedVideoFileURL(projectId: project.id)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                projectBadge

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(project.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        AppChip(systemImage: "photo.stack", text: "\(project.frames.count)")
                        AppChip(systemImage: "clock", text: String(format: "%.1fs", project.duration))
                        AppChip(systemImage: "film", text: "\(project.fps) fps")
                    }
                }
            }

            actionRow
        }
        .appCard()
        .task(id: project.id) {
            await loadThumbnailIfNeeded()
        }
    }

    private var projectBadge: some View {
        Group {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                    }
            } else {
                AppIconBadge(systemImage: "film")
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            ProjectCardActionButton(
                title: LocalizedStringKey("home.project.edit"),
                systemImage: "pencil",
                style: .prominent
            ) {
                onEdit()
            }

            if hasPlayableVideo {
                ProjectCardActionButton(
                    title: LocalizedStringKey("home.project.play"),
                    systemImage: "play.fill",
                    style: .regular
                ) {
                    onPlay()
                }
            }

            ProjectCardActionButton(
                title: LocalizedStringKey("general.delete"),
                systemImage: "trash",
                style: canDelete ? .destructive : .proLocked
            ) {
                if canDelete {
                    onDelete()
                } else {
                    onRequestDeleteUpgrade()
                }
            }
        }
    }

    private func loadThumbnailIfNeeded() async {
        guard thumbnailImage == nil else { return }

        let firstFrame = project.frames.min(by: { $0.orderIndex < $1.orderIndex })
        guard let firstFrame else { return }

        thumbnailImage = await MovieStorage.shared.loadFrame(fileName: firstFrame.localFileName, projectId: project.id)
    }
}

private struct ProjectCardActionButton: View {
    enum Style {
        case prominent
        case regular
        case destructive
        case proLocked
    }

    let title: LocalizedStringKey
    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundStyle)
        .background(backgroundView)
        .overlay(overlayView)
        .accessibilityLabel(title)
    }

    private var foregroundStyle: AnyShapeStyle {
        switch style {
        case .prominent:
            return AnyShapeStyle(Color.white)
        case .regular:
            return AnyShapeStyle(Color.accentColor)
        case .destructive:
            return AnyShapeStyle(AppTheme.Colors.destructive)
        case .proLocked:
            return AnyShapeStyle(proGradient)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .prominent:
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlCornerRadius, style: .continuous)
                .fill(Color.accentColor)
        case .regular, .destructive, .proLocked:
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.elevatedSurface)
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Metrics.controlCornerRadius, style: .continuous)

        switch style {
        case .prominent:
            shape
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        case .regular:
            shape
                .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
        case .destructive:
            shape
                .strokeBorder(AppTheme.Colors.destructive.opacity(0.35), lineWidth: 1.5)
        case .proLocked:
            shape
                .strokeBorder(proGradient, lineWidth: 2)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(proGradient))
                        .offset(x: 8, y: -8)
                        .accessibilityHidden(true)
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

