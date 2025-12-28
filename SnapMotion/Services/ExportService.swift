//
//  ExportService.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import UIKit

actor ExportService {
    private let videoRenderer = VideoRenderer()
    private let storage = MovieStorage.shared
    
    func exportVideo(project: MovieProject) async throws -> URL {
        let frameImages = try await loadFrameImages(for: project)
        
        guard !frameImages.isEmpty else {
            throw ExportError.noFrames
        }
        
        let titleText = project.titleCardText
        let creditsMode = project.creditsModeEnum
        let plainCreditsText = project.plainCreditsText
        let structuredCreditsJSON = project.structuredCreditsJSON
        
        let creditsText = await getCreditsText(
            mode: creditsMode,
            plainText: plainCreditsText,
            structuredJSON: structuredCreditsJSON
        )
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try await videoRenderer.renderVideo(
            frames: frameImages,
            fps: project.fps,
            titleCard: titleText,
            creditsText: creditsText,
            outputURL: tempURL
        )
        
        let savedURL = try await storage.saveExportedVideo(tempURL, projectId: project.id)
        
        try? FileManager.default.removeItem(at: tempURL)
        
        return savedURL
    }
    
    func exportImages(project: MovieProject) async throws -> [URL] {
        let frameImages = try await loadFrameImages(for: project)
        
        guard !frameImages.isEmpty else {
            throw ExportError.noFrames
        }
        
        var urls: [URL] = []
        
        for (index, image) in frameImages.enumerated() {
            let fileName = String(format: "frame_%04d.jpg", index)
            let url = try await storage.saveFrame(image, fileName: fileName, projectId: project.id)
            urls.append(url)
        }
        
        return urls
    }
    
    private func loadFrameImages(for project: MovieProject) async throws -> [UIImage] {
        var images: [UIImage] = []
        
        for frame in project.frames.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if let image = await storage.loadFrame(fileName: frame.localFileName, projectId: project.id) {
                images.append(image)
            }
        }
        
        return images
    }
    
    private func getCreditsText(
        mode: CreditsMode,
        plainText: String?,
        structuredJSON: String?
    ) async -> String? {
        await MainActor.run {
            switch mode {
            case .plain:
                return plainText
            case .structured:
                guard let jsonString = structuredJSON,
                      let data = jsonString.data(using: .utf8),
                      let credits = try? JSONDecoder().decode(StructuredCredits.self, from: data) else {
                    return nil
                }
                
                var lines: [String] = []
                if !credits.director.isEmpty {
                    lines.append("Director: \(credits.director)")
                }
                if !credits.animator.isEmpty {
                    lines.append("Animator: \(credits.animator)")
                }
                if !credits.music.isEmpty {
                    lines.append("Music: \(credits.music)")
                }
                if !credits.thanks.isEmpty {
                    lines.append("Thanks: \(credits.thanks)")
                }
                
                return lines.isEmpty ? nil : lines.joined(separator: "\n")
            }
        }
    }
    
    enum ExportError: LocalizedError {
        case noFrames
        case renderFailed
        
        var errorDescription: String? {
            switch self {
            case .noFrames:
                return "No frames to export"
            case .renderFailed:
                return "Failed to render video"
            }
        }
    }
}

