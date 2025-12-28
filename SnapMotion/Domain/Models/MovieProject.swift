//
//  MovieProject.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

enum CreditsMode: String, Codable {
    case plain
    case structured
}

@Model
final class MovieProject {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var fps: Int
    var resolutionPreset: String
    var exportedVideoURL: String?
    var titleCardText: String?
    var creditsMode: String
    var plainCreditsText: String?
    var structuredCreditsJSON: String?
    
    @Relationship(deleteRule: .cascade, inverse: \FrameAsset.project)
    var frames: [FrameAsset]
    
    init(
        id: UUID = UUID(),
        title: String,
        fps: Int = 5,
        resolutionPreset: String = "1080p"
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.fps = fps
        self.resolutionPreset = resolutionPreset
        self.creditsMode = CreditsMode.plain.rawValue
        self.frames = []
    }
    
    var creditsModeEnum: CreditsMode {
        get { CreditsMode(rawValue: creditsMode) ?? .plain }
        set { creditsMode = newValue.rawValue }
    }
    
    var duration: TimeInterval {
        let frameCount = frames.count
        guard frameCount > 0, fps > 0 else { return 0 }
        return Double(frameCount) / Double(fps)
    }
    
    func canDelete(isPro: Bool) -> Bool {
        return isPro
    }
}

