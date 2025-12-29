//
//  ExportService.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import UIKit

actor ExportService {
    private let videoRenderer = VideoRenderer()
    private let audioVideoMergeService = AudioVideoMergeService()
    private let storage = MovieStorage.shared
    
    func exportVideo(project: MovieProject) async throws -> URL {
        let frameImages = try await loadFrameImages(for: project)
        
        guard !frameImages.isEmpty else {
            throw ExportError.noFrames
        }
        
        let titleText = project.titleCardText
        let creditsText = ExportService.buildCreditsText(project: project)
        
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

        let finalVideoURL: URL
        if let mergedURL = try await mergeAudioIfNeeded(project: project, videoURL: tempURL) {
            finalVideoURL = mergedURL
        } else {
            finalVideoURL = tempURL
        }
        
        let savedURL = try await storage.saveExportedVideo(finalVideoURL, projectId: project.id)
        
        try? FileManager.default.removeItem(at: tempURL)
        if finalVideoURL != tempURL {
            try? FileManager.default.removeItem(at: finalVideoURL)
        }
        
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
    
    static func buildCreditsText(project: MovieProject) -> String? {
        switch project.creditsModeEnum {
        case .plain:
            let trimmed = project.plainCreditsText?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty == false) ? trimmed : nil
        case .structured:
            guard let jsonString = project.structuredCreditsJSON,
                  let data = jsonString.data(using: .utf8),
                  let credits = try? JSONDecoder().decode(StructuredCredits.self, from: data) else {
                return nil
            }
            
            var lines: [String] = []
            if !credits.director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("\(String(localized: "titleCredits.director")): \(credits.director)")
            }
            if !credits.animator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("\(String(localized: "titleCredits.animator")): \(credits.animator)")
            }
            if !credits.music.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("\(String(localized: "titleCredits.music")): \(credits.music)")
            }
            if !credits.thanks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("\(String(localized: "titleCredits.thanks")): \(credits.thanks)")
            }
            
            for extra in credits.extras {
                let label = extra.label.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = extra.value.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if label.isEmpty, !value.isEmpty {
                    lines.append(value)
                } else if !label.isEmpty, !value.isEmpty {
                    lines.append("\(label): \(value)")
                }
            }
            
            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        }
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

    private func mergeAudioIfNeeded(project: MovieProject, videoURL: URL) async throws -> URL? {
        guard let audioFileName = project.audioFileName, !audioFileName.isEmpty else { return nil }
        let duration = max(0, project.audioDurationSeconds ?? 0)
        guard duration > 0 else { return nil }

        let start = max(0, project.audioSelectionStartSeconds ?? 0)
        let end = max(0, min(project.audioSelectionEndSeconds ?? duration, duration))
        guard end > start else { return nil }

        let titleSeconds: Double = {
            let titleText = project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return titleText.isEmpty ? 0 : 2
        }()
        let creditsSeconds: Double = {
            let creditsText = ExportService.buildCreditsText(project: project) ?? ""
            let trimmed = creditsText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return 0 }
            let lineCount = max(1, trimmed.split(whereSeparator: \.isNewline).count)
            return max(4, min(24, 2.0 + (Double(lineCount) * 1.15)))
        }()
        let totalVideoSeconds = titleSeconds + project.duration + creditsSeconds
        guard totalVideoSeconds > 0 else { return nil }

        let segmentDurationSeconds = min(end - start, totalVideoSeconds)
        guard segmentDurationSeconds > 0 else { return nil }

        let audioURL = await storage.audioFileURL(projectId: project.id, fileName: audioFileName)

        let mergedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        try await audioVideoMergeService.mergeVideo(
            videoURL: videoURL,
            audioURL: audioURL,
            audioStartSeconds: start,
            audioDurationSeconds: segmentDurationSeconds,
            audioInsertAtSeconds: 0,
            outputURL: mergedURL
        )

        return mergedURL
    }
    
    enum ExportError: LocalizedError {
        case noFrames
        case renderFailed
        
        var errorDescription: String? {
            switch self {
            case .noFrames:
                return String(localized: "error.export.noFrames")
            case .renderFailed:
                return String(localized: "error.export.renderFailed")
            }
        }
    }
}

