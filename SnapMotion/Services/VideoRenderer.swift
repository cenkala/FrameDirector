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
        
        if let titleCard = titleCard?.trimmingCharacters(in: .whitespacesAndNewlines),
           !titleCard.isEmpty {
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
        
        if let creditsText = creditsText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !creditsText.isEmpty {
            let layout = makeScrollingCreditsLayout(text: creditsText, size: frameSize, fps: fps)
            for i in 0..<layout.frameCount {
                let t = layout.frameCount <= 1 ? 1.0 : Double(i) / Double(layout.frameCount - 1)
                let y = layout.startY + CGFloat(t) * (layout.endY - layout.startY)
                
                let image = layout.renderer.image { context in
                    UIColor.black.setFill()
                    context.fill(CGRect(origin: .zero, size: frameSize))
                    
                    let textRect = CGRect(
                        x: layout.paddingX,
                        y: y,
                        width: layout.availableWidth,
                        height: layout.textHeight
                    )
                    
                    layout.attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                }
                
                let presentationTime = CMTime(value: frameCount, timescale: CMTimeScale(fps))
                try await appendFrame(image, to: adaptor, at: presentationTime)
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
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineSpacing = max(6, size.height * 0.008)
            
            let baseFontSize = max(50, min(104, size.height * 0.095))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: baseFontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let paddingX = max(36, size.width * 0.08)
            let paddingY = max(28, size.height * 0.08)
            let bounding = CGRect(
                x: paddingX,
                y: paddingY,
                width: size.width - (paddingX * 2),
                height: size.height - (paddingY * 2)
            )
            
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let measured = attributed.boundingRect(
                with: bounding.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).integral
            
            let drawRect = CGRect(
                x: bounding.minX,
                y: bounding.minY + max(0, (bounding.height - measured.height) / 2),
                width: bounding.width,
                height: measured.height
            )
            
            attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }
    
    private func makeScrollingCreditsLayout(text: String, size: CGSize, fps: Int) -> ScrollingCreditsLayout {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFPS = max(fps, 1)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = max(10, size.height * 0.012)
        
        let fontSize = max(32, min(72, size.height * 0.062))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributed = NSAttributedString(string: trimmed, attributes: attributes)
        let paddingX = max(40, size.width * 0.10)
        let paddingY = max(40, size.height * 0.10)
        let availableWidth = size.width - (paddingX * 2)
        
        let measured = attributed.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        
        let textHeight = max(measured.height, fontSize * 1.5)
        // Start closer to the visible area so scrolling begins immediately.
        let startY = size.height - paddingY
        let endY = -textHeight - paddingY
        let travelDistance = startY - endY
        
        let pointsPerSecond = max(180, size.height * 0.25)
        let durationSeconds = max(3, min(24, Double(travelDistance) / Double(pointsPerSecond)))
        let frameCount = max(safeFPS * 3, Int((durationSeconds * Double(safeFPS)).rounded(.up)))
        
        return ScrollingCreditsLayout(
            renderer: renderer,
            attributed: attributed,
            paddingX: paddingX,
            availableWidth: availableWidth,
            textHeight: textHeight,
            startY: startY,
            endY: endY,
            frameCount: frameCount
        )
    }
    
    private struct ScrollingCreditsLayout {
        let renderer: UIGraphicsImageRenderer
        let attributed: NSAttributedString
        let paddingX: CGFloat
        let availableWidth: CGFloat
        let textHeight: CGFloat
        let startY: CGFloat
        let endY: CGFloat
        let frameCount: Int
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

