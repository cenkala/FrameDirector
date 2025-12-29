//
//  AudioVideoMergeService.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalılar on 29.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import AVFoundation
import Foundation

actor AudioVideoMergeService {
    private struct UncheckedSendable<T>: @unchecked Sendable {
        let value: T
        init(_ value: T) { self.value = value }
    }

    func mergeVideo(
        videoURL: URL,
        audioURL: URL,
        audioStartSeconds: Double,
        audioDurationSeconds: Double,
        audioInsertAtSeconds: Double,
        outputURL: URL
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let composition = AVMutableComposition()

        guard let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw MergeError.missingVideoTrack
        }

        let videoDuration = try await videoAsset.load(.duration)
        guard videoDuration.isValid, videoDuration > .zero else {
            throw MergeError.invalidVideoDuration
        }

        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceVideoTrack,
            at: .zero
        )

        compositionVideoTrack?.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        if let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            let audioAssetDuration = try await audioAsset.load(.duration)
            let safeAudioStart = max(0, audioStartSeconds)
            let safeDuration = max(0, audioDurationSeconds)

            let startTime = CMTime(seconds: safeAudioStart, preferredTimescale: 600)
            let segmentDuration = CMTime(seconds: safeDuration, preferredTimescale: 600)
            let maxAvailable = max(.zero, audioAssetDuration - startTime)
            let timeRangeDuration = min(segmentDuration, maxAvailable)

            if timeRangeDuration > .zero {
                let timeRange = CMTimeRange(start: startTime, duration: timeRangeDuration)
                let insertAt = CMTime(seconds: max(0, audioInsertAtSeconds), preferredTimescale: 600)

                try compositionAudioTrack?.insertTimeRange(
                    timeRange,
                    of: sourceAudioTrack,
                    at: insertAt
                )
            }
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw MergeError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        try await export(exportSession)
    }

    private func export(_ exportSession: AVAssetExportSession) async throws {
        let session = UncheckedSendable(exportSession)
        try await withCheckedThrowingContinuation { continuation in
            session.value.exportAsynchronously {
                switch session.value.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: session.value.error ?? MergeError.exportFailed)
                case .cancelled:
                    continuation.resume(throwing: session.value.error ?? MergeError.exportCancelled)
                default:
                    continuation.resume(throwing: session.value.error ?? MergeError.exportFailed)
                }
            }
        }
    }

    enum MergeError: LocalizedError {
        case missingVideoTrack
        case invalidVideoDuration
        case exportSessionCreationFailed
        case exportFailed
        case exportCancelled

        var errorDescription: String? {
            switch self {
            case .missingVideoTrack:
                return "Missing video track."
            case .invalidVideoDuration:
                return "Invalid video duration."
            case .exportSessionCreationFailed:
                return "Failed to create export session."
            case .exportFailed:
                return "Failed to export merged video."
            case .exportCancelled:
                return "Export cancelled."
            }
        }
    }
}


