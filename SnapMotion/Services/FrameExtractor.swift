//
//  FrameExtractor.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import AVFoundation
import UIKit

actor FrameExtractor {
    func extractFrames(from videoURL: URL, fps: Int = 12) async throws -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let frameInterval = 1.0 / Double(fps)
        let frameCount = Int(durationSeconds * Double(fps))
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.appliesPreferredTrackTransform = true
        
        var frames: [UIImage] = []
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
            
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                let image = UIImage(cgImage: cgImage)
                frames.append(image)
            } catch {
                print("Failed to extract frame at \(time.seconds): \(error)")
            }
        }
        
        return frames
    }
}

