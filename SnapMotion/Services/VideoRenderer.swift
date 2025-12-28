//
//  VideoRenderer.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import AVFoundation
import UIKit
import CoreGraphics

actor VideoRenderer {
    func renderVideo(
        frames: [UIImage],
        fps: Int,
        titleCard: String?,
        creditsText: String?,
        outputURL: URL
    ) async throws {
        guard !frames.isEmpty else {
            throw RenderError.noFrames
        }
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        let frameSize = frames[0].size
        
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: frameSize.width,
            AVVideoHeightKey: frameSize.height
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: frameSize.width,
                kCVPixelBufferHeightKey as String: frameSize.height
            ]
        )
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        var frameCount: Int64 = 0
        
        if let titleCard = titleCard, !titleCard.isEmpty {
            let titleImage = createTitleCard(text: titleCard, size: frameSize)
            let titleFrameCount = fps * 2
            for _ in 0..<titleFrameCount {
                let presentationTime = CMTime(value: frameCount, timescale: CMTimeScale(fps))
                try await appendFrame(titleImage, to: adaptor, at: presentationTime)
                frameCount += 1
            }
        }
        
        for frame in frames {
            let presentationTime = CMTime(value: frameCount, timescale: CMTimeScale(fps))
            try await appendFrame(frame, to: adaptor, at: presentationTime)
            frameCount += 1
        }
        
        if let creditsText = creditsText, !creditsText.isEmpty {
            let creditsImage = createCreditsCard(text: creditsText, size: frameSize)
            let creditsFrameCount = fps * 3
            for _ in 0..<creditsFrameCount {
                let presentationTime = CMTime(value: frameCount, timescale: CMTimeScale(fps))
                try await appendFrame(creditsImage, to: adaptor, at: presentationTime)
                frameCount += 1
            }
        }
        
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        
        if videoWriter.status != .completed {
            throw RenderError.writingFailed
        }
    }
    
    private func appendFrame(_ image: UIImage, to adaptor: AVAssetWriterInputPixelBufferAdaptor, at time: CMTime) async throws {
        while !adaptor.assetWriterInput.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        
        guard let pixelBuffer = await image.pixelBuffer() else {
            throw RenderError.pixelBufferFailed
        }
        
        if !adaptor.append(pixelBuffer, withPresentationTime: time) {
            throw RenderError.appendFailed
        }
    }
    
    private func createTitleCard(text: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func createCreditsCard(text: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 8
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let padding: CGFloat = 40
            let textRect = CGRect(
                x: padding,
                y: (size.height - 300) / 2,
                width: size.width - (padding * 2),
                height: 300
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    enum RenderError: LocalizedError {
        case noFrames
        case writingFailed
        case pixelBufferFailed
        case appendFailed
        
        var errorDescription: String? {
            switch self {
            case .noFrames:
                return "No frames to render"
            case .writingFailed:
                return "Video writing failed"
            case .pixelBufferFailed:
                return "Failed to create pixel buffer"
            case .appendFailed:
                return "Failed to append frame"
            }
        }
    }
}

extension UIImage {
    @MainActor
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        return buffer
    }
}

