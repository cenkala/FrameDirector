//
//  PlayerView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import AVKit

struct PlayerView: View {
    let project: MovieProject
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack(spacing: AppTheme.Metrics.contentSpacing) {
            if let player = player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                            .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                    }
                    .onAppear {
                        player.play()
                    }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(LocalizedStringKey("player.loadingVideo"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .appCard()
            }
        }
        .padding(AppTheme.Metrics.screenPadding)
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(.accentColor)
        .appScreenBackground()
        .onAppear {
            loadVideo()
        }
    }
    
    private func loadVideo() {
        var candidates: [URL] = []

        if let urlString = project.exportedVideoURL,
           let url = URL(string: urlString) {
            candidates.append(url)
        }

        candidates.append(MovieStorage.exportedVideoFileURL(projectId: project.id))

        guard let url = candidates.first(where: { url in
            if url.isFileURL {
                return FileManager.default.fileExists(atPath: url.path)
            }
            return true
        }) else {
            return
        }

        player = AVPlayer(url: url)
    }
}

