//
//  ProjectCardView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct ProjectCardView: View {
    let project: MovieProject
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                AppIconBadge(systemImage: "film")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(project.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        if project.exportedVideoURL != nil {
                            AppChip(systemImage: "checkmark.circle.fill", textKey: LocalizedStringKey("general.done"))
                        }
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

                if project.exportedVideoURL != nil {
                    Button {
                        onPlay()
                    } label: {
                        Label(LocalizedStringKey("home.project.play"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label(LocalizedStringKey("home.project.edit"), systemImage: "pencil")
                    }

                    if project.exportedVideoURL != nil {
                        Button {
                            onPlay()
                        } label: {
                            Label(LocalizedStringKey("home.project.play"), systemImage: "play.fill")
                        }
                    }

                    Button(role: .destructive) {
                        if canDelete {
                            onDelete()
                        }
                    } label: {
                        Label(LocalizedStringKey("general.delete"), systemImage: "trash")
                    }
                    .disabled(!canDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .appCard()
    }
}

