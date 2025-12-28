//
//  ProjectCardView.swift
//  SnapMotion
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

            HStack(spacing: 10) {
                Button {
                    onEdit()
                } label: {
                    Label(LocalizedStringKey("home.project.edit"), systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                if hasPlayableVideo {
                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }

                Button(role: .destructive) {
                    if canDelete {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.Colors.destructive)
                .disabled(!canDelete)
            }
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

    private func loadThumbnailIfNeeded() async {
        guard thumbnailImage == nil else { return }

        let firstFrame = project.frames.min(by: { $0.orderIndex < $1.orderIndex })
        guard let firstFrame else { return }

        thumbnailImage = await MovieStorage.shared.loadFrame(fileName: firstFrame.localFileName, projectId: project.id)
    }
}

