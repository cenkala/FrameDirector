//
//  EditorViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData
import AVFoundation

extension Date {
    var roundedTo10Seconds: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        let roundedSeconds = (components.second ?? 0) / 10 * 10
        var newComponents = components
        newComponents.second = roundedSeconds
        return calendar.date(from: newComponents) ?? self
    }
}

enum TimelineItem: Identifiable {
    case titleFrame(index: Int, total: Int)
    case singleFrame(FrameAsset)
    case creditsFrame(index: Int, total: Int)

    var id: String {
        switch self {
        case .titleFrame(let index, _):
            return "title-\(index)"
        case .singleFrame(let frame):
            return frame.id.uuidString
        case .creditsFrame(let index, _):
            return "credits-\(index)"
        }
    }

    var frames: [FrameAsset] {
        switch self {
        case .titleFrame, .creditsFrame:
            return []
        case .singleFrame(let frame):
            return [frame]
        }
    }
}

@MainActor
@Observable
final class EditorViewModel {
    let project: MovieProject
    private let modelContext: ModelContext
    private let featureGate: FeatureGateService

    var isPlaying = false
    var currentFrameIndex = 0
    var showTitleCredits = false
    var previewOverlay: PreviewOverlay = .none

    private var playbackTask: Task<Void, Never>?
    private var overlayTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var audioStopTask: Task<Void, Never>?
    var audioWaveform: [CGFloat] = []

    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
        self.featureGate = FeatureGateService.shared

        if let fileName = project.audioFileName,
           !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleAudioWaveformExtraction(fileName: fileName)
        }
    }

    var hasTitleCard: Bool {
        let title = project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !title.isEmpty
    }

    var hasCredits: Bool {
        let creditsText = ExportService.buildCreditsText(project: project) ?? ""
        return !creditsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var titleFrameCount: Int {
        guard hasTitleCard else { return 0 }
        let fps = max(project.fps, 1)
        return fps * 2
    }

    var creditsFrameCount: Int {
        guard hasCredits else { return 0 }
        let fps = max(project.fps, 1)
        let creditsText = ExportService.buildCreditsText(project: project) ?? ""
        let lineCount = max(1, creditsText.split(whereSeparator: \.isNewline).count)
        let seconds = max(4, min(24, 2.0 + (Double(lineCount) * 1.15)))
        return max(fps * 3, Int((seconds * Double(fps)).rounded(.up)))
    }

    var totalTimelineDurationSeconds: Double {
        let fps = max(project.fps, 1)
        return Double(totalFrameCount) / Double(fps)
    }

    func frameIndex(forTimelineIndex timelineIndex: Int) -> Int? {
        let framesStart = titleFrameCount
        let framesEnd = framesStart + sortedFrames.count
        guard timelineIndex >= framesStart, timelineIndex < framesEnd else { return nil }
        return timelineIndex - framesStart
    }

    var hasAudio: Bool {
        project.audioFileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var audioDurationSeconds: Double {
        max(0, project.audioDurationSeconds ?? 0)
    }

    var audioSelectionStartSeconds: Double {
        max(0, project.audioSelectionStartSeconds ?? 0)
    }

    var audioSelectionEndSeconds: Double {
        let end = project.audioSelectionEndSeconds ?? audioDurationSeconds
        return max(0, min(end, audioDurationSeconds))
    }

    func updateAudioSelection(startSeconds: Double, endSeconds: Double) {
        let minDuration = 0.1
        let duration = max(0, audioDurationSeconds)
        guard duration > 0 else { return }

        var start = max(0, min(startSeconds, duration))
        var end = max(0, min(endSeconds, duration))

        if end - start < minDuration {
            end = min(duration, start + minDuration)
            if end - start < minDuration {
                start = max(0, end - minDuration)
            }
        }

        project.audioSelectionStartSeconds = start
        project.audioSelectionEndSeconds = end
        project.updatedAt = Date()
        try? modelContext.save()
    }

    func addAudio(fromPickedURL url: URL) async throws {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard playable else { throw AudioImportError.notPlayable }
        guard !audioTracks.isEmpty else { throw AudioImportError.noAudioTrack }

        if let existing = project.audioFileName, !existing.isEmpty {
            try? await MovieStorage.shared.deleteAudioFile(projectId: project.id, fileName: existing)
        }

        let saved = try await MovieStorage.shared.saveAudioFile(sourceURL: url, projectId: project.id)
        guard saved.durationSeconds >= 0.1 else { throw AudioImportError.tooShort }

        project.audioFileName = saved.fileName
        project.audioDisplayName = saved.displayName
        project.audioDurationSeconds = saved.durationSeconds

        let defaultEnd = min(saved.durationSeconds, max(0.1, totalTimelineDurationSeconds))
        project.audioSelectionStartSeconds = 0
        project.audioSelectionEndSeconds = max(0.1, defaultEnd)

        project.updatedAt = Date()
        try? modelContext.save()

        audioWaveform = []
        scheduleAudioWaveformExtraction(fileName: saved.fileName)
    }

    private func scheduleAudioWaveformExtraction(fileName: String) {
        let projectId = project.id
        let fps = max(project.fps, 1)

        Task.detached { [weak self] in
            guard let self else { return }
            let url = await MovieStorage.shared.audioFileURL(projectId: projectId, fileName: fileName)
            let waveform = (try? AudioWaveformExtractor.extract(url: url, fps: fps)) ?? []
            await MainActor.run {
                self.audioWaveform = waveform
            }
        }
    }
    
    var sortedFrames: [FrameAsset] {
        project.frames.sorted { $0.orderIndex < $1.orderIndex }
    }

    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        let titleCount = titleFrameCount
        if titleCount > 0 {
            for i in 0..<titleCount {
                items.append(.titleFrame(index: i, total: titleCount))
            }
        }

        for frame in sortedFrames {
            items.append(.singleFrame(frame))
        }

        let creditsCount = creditsFrameCount
        if creditsCount > 0 {
            for i in 0..<creditsCount {
                items.append(.creditsFrame(index: i, total: creditsCount))
            }
        }

        return items
    }

    var totalFrameCount: Int {
        timelineItems.count
    }

    var currentTimelineItemIndex: Int {
        var frameCount = 0
        for (itemIndex, item) in timelineItems.enumerated() {
            let itemFrameCount = item.frames.count
            if currentFrameIndex >= frameCount && currentFrameIndex < frameCount + itemFrameCount {
                return itemIndex
            }
            frameCount += itemFrameCount
        }
        return 0
    }

    var currentFrameInTimelineItem: Int {
        var frameCount = 0
        for item in timelineItems {
            let itemFrameCount = item.frames.count
            if currentFrameIndex >= frameCount && currentFrameIndex < frameCount + itemFrameCount {
                return currentFrameIndex - frameCount
            }
            frameCount += itemFrameCount
        }
        return 0
    }
    
    var canExport: Bool {
        !project.frames.isEmpty
    }
    
    var exceedsFreeDuration: Bool {
        if featureGate.isPro { return false }
        return project.duration > ProjectLimits.freeMaxDurationSeconds
    }
    
    var maxAllowedFrames: Int? {
        ProjectLimits.maxAllowedFrames(fps: project.fps, isPro: featureGate.isPro)
    }
    
    func canAddMoreFrames() -> Bool {
        guard let maxFrames = maxAllowedFrames else { return true }
        return project.frames.count < maxFrames
    }


    func moveFrameById(_ frameId: UUID, toGlobalIndex destinationIndex: Int) {
        let frames = sortedFrames
        guard let sourceIndex = frames.firstIndex(where: { $0.id == frameId }) else { return }
        let safeDestination = max(0, min(destinationIndex, max(frames.count - 1, 0)))
        moveFrame(from: sourceIndex, to: safeDestination)
    }

    func selectFrame(at globalIndex: Int) {
        guard globalIndex >= 0 && globalIndex < totalFrameCount else { return }
        overlayTask?.cancel()
        overlayTask = nil
        currentFrameIndex = globalIndex

        refreshPreviewOverlayForCurrentFrameIndex()
    }

    func getGlobalFrameIndex(for frame: FrameAsset) -> Int {
        let frames = sortedFrames
        guard let index = frames.firstIndex(where: { $0.id == frame.id }) else { return 0 }
        return titleFrameCount + index
    }

    func moveTimelineItem(from sourceItemIndex: Int, to destinationItemIndex: Int) {
        let items = timelineItems
        guard !items.isEmpty else { return }
        guard sourceItemIndex >= 0, sourceItemIndex < items.count else { return }
        guard destinationItemIndex >= 0, destinationItemIndex <= items.count else { return }

        let frames = sortedFrames
        guard !frames.isEmpty else { return }

        func startFrameIndex(for itemIndex: Int) -> Int {
            guard itemIndex > 0 else { return 0 }
            return items.prefix(itemIndex).reduce(0) { $0 + $1.frames.count }
        }

        let sourceStart = startFrameIndex(for: sourceItemIndex)
        let sourceCount = items[sourceItemIndex].frames.count
        let sourceEnd = sourceStart + sourceCount
        guard sourceStart >= 0, sourceEnd <= frames.count else { return }

        var destinationStart = startFrameIndex(for: min(destinationItemIndex, items.count))
        // Eğer ileri doğru taşıyorsak, çıkarılan blok kadar hedef index kayar.
        if destinationItemIndex > sourceItemIndex {
            destinationStart -= sourceCount
        }
        destinationStart = max(0, min(destinationStart, frames.count - sourceCount))

        var newFrames = frames
        let movingBlock = Array(newFrames[sourceStart..<sourceEnd])
        newFrames.removeSubrange(sourceStart..<sourceEnd)
        let safeInsertIndex = max(0, min(destinationStart, newFrames.count))
        newFrames.insert(contentsOf: movingBlock, at: safeInsertIndex)

        for (index, frame) in newFrames.enumerated() {
            frame.orderIndex = index
        }

        project.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteFrame(at index: Int) {
        let frames = sortedFrames
        guard index < frames.count else { return }
        let frame = frames[index]
        
        if let projectIndex = project.frames.firstIndex(where: { $0.id == frame.id }) {
            modelContext.delete(frame)
            project.frames.remove(at: projectIndex)
            reorderFrames()
            try? modelContext.save()
            
            Task {
                try? await MovieStorage.shared.deleteFrameFile(fileName: frame.localFileName, projectId: project.id)
            }
        }
    }
    
    func duplicateFrame(at index: Int) {
        let frames = sortedFrames
        guard index < frames.count else { return }
        guard canAddMoreFrames() else { return }

        let originalFrame = frames[index]
        let newFrame = FrameAsset(
            localFileName: "\(UUID().uuidString).jpg",
            orderIndex: originalFrame.orderIndex + 1,
            source: originalFrame.sourceEnum,
            stackId: nil
        )

        // Insert the new frame at the correct position in the array
        newFrame.project = project
        project.frames.append(newFrame)

        // Shift orderIndex of frames that come after the new frame
        for frame in frames where frame.orderIndex >= newFrame.orderIndex {
            frame.orderIndex += 1
        }

        project.updatedAt = Date()
        try? modelContext.save()

        Task {
            try? await MovieStorage.shared.duplicateFrameFile(
                from: originalFrame.localFileName,
                to: newFrame.localFileName,
                projectId: project.id
            )
        }
    }
    
    func moveFrame(from source: Int, to destination: Int) {
        let frames = sortedFrames
        guard source < frames.count, destination < frames.count else { return }
        
        let frameToMove = frames[source]
        
        if source < destination {
            frameToMove.orderIndex = frames[destination].orderIndex
            for i in (source + 1)...destination {
                frames[i].orderIndex -= 1
            }
        } else {
            frameToMove.orderIndex = frames[destination].orderIndex
            for i in destination..<source {
                frames[i].orderIndex += 1
            }
        }
        
        reorderFrames()
        try? modelContext.save()
    }
    
    func updateFPS(_ newFPS: Int) {
        project.fps = newFPS
        project.updatedAt = Date()
        try? modelContext.save()
    }

    func removeTitleCard() {
        stopPlayback()
        project.titleCardText = nil
        project.updatedAt = Date()
        try? modelContext.save()
        clampCurrentFrameIndex()
        refreshPreviewOverlayForCurrentFrameIndex()
    }

    func removeCredits() {
        stopPlayback()
        project.plainCreditsText = nil
        project.structuredCreditsJSON = nil
        project.creditsModeEnum = .plain
        project.updatedAt = Date()
        try? modelContext.save()
        clampCurrentFrameIndex()
        refreshPreviewOverlayForCurrentFrameIndex()
    }
    
    func refreshPreviewOverlayForCurrentFrameIndex() {
        guard !isPlaying else { return }
        guard currentFrameIndex >= 0 && currentFrameIndex < totalFrameCount else {
            previewOverlay = .none
            return
        }

        switch timelineItems[currentFrameIndex] {
        case .singleFrame:
            previewOverlay = .none

        case .titleFrame:
            let titleText = project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            previewOverlay = titleText.isEmpty ? .none : .title(text: titleText)

        case .creditsFrame(let index, let total):
            let creditsText = ExportService.buildCreditsText(project: project) ?? ""
            let trimmed = creditsText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                previewOverlay = .none
                return
            }
            let progress = total <= 1 ? 1.0 : Double(index) / Double(total - 1)
            previewOverlay = .credits(text: trimmed, progress: progress)
        }
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    func stopPlayback() {
        overlayTask?.cancel()
        overlayTask = nil
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        previewOverlay = .none
        stopAudioPreview()
    }
    
    func showTitleCardPreview() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        stopAudioPreview()
        
        overlayTask?.cancel()
        overlayTask = nil
        
        let titleText = project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !titleText.isEmpty else {
            previewOverlay = .none
            return
        }
        
        previewOverlay = .title(text: titleText)
    }
    
    func showCreditsPreview() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        stopAudioPreview()
        
        overlayTask?.cancel()
        overlayTask = nil
        
        let creditsText = ExportService.buildCreditsText(project: project) ?? ""
        guard !creditsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            previewOverlay = .none
            return
        }
        
        previewOverlay = .credits(text: creditsText, progress: 0)
        
        let fps = max(project.fps, 1)
        let lineCount = max(1, creditsText.split(whereSeparator: \.isNewline).count)
        let seconds = max(4, min(24, 2.0 + (Double(lineCount) * 1.15)))
        let frameCount = max(fps * 3, Int((seconds * Double(fps)).rounded(.up)))
        let nanosPerFrame = UInt64(1_000_000_000 / fps)
        
        overlayTask = Task { [weak self] in
            guard let self else { return }
            for i in 0..<frameCount {
                if Task.isCancelled { return }
                let progress = frameCount <= 1 ? 1.0 : Double(i) / Double(frameCount - 1)
                await MainActor.run {
                    if !self.isPlaying {
                        self.previewOverlay = .credits(text: creditsText, progress: progress)
                    }
                }
                try? await Task.sleep(nanoseconds: nanosPerFrame)
            }
        }
    }
    
    private func startPlayback() {
        guard project.fps > 0, !sortedFrames.isEmpty else { return }
        
        overlayTask?.cancel()
        overlayTask = nil
        
        isPlaying = true
        stopAudioPreview()
        playbackTask?.cancel()
        
        playbackTask = Task { [weak self] in
            guard let self else { return }
            
            let fps = max(self.project.fps, 1)
            let nanosPerFrame = UInt64(1_000_000_000 / fps)
            
            let titleText = self.project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines)
            let creditsText = ExportService.buildCreditsText(project: self.project)
            
            self.currentFrameIndex = 0
            
            let titleDurationFrames = (titleText?.isEmpty == false) ? (fps * 2) : 0
            let creditsDurationFrames: Int = {
                guard let creditsText, !creditsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
                let lineCount = max(1, creditsText.split(whereSeparator: \.isNewline).count)
                let seconds = max(4, min(24, 2.0 + (Double(lineCount) * 1.15)))
                return max(fps * 3, Int((seconds * Double(fps)).rounded(.up)))
            }()
            
            enum Phase {
                case title(remaining: Int)
                case frames
                case credits(remaining: Int, total: Int)
            }
            
            var phase: Phase = titleDurationFrames > 0 ? .title(remaining: titleDurationFrames) : .frames
            var audioDidStart = false
            var framesPhaseLocalIndex = 0
            var creditsPhaseLocalIndex = 0
            
            while !Task.isCancelled {
                let frames = self.sortedFrames
                if frames.isEmpty {
                    self.stopPlayback()
                    return
                }
                
                switch phase {
                case .title(let remaining):
                    if !audioDidStart {
                        audioDidStart = true
                        self.startAudioPreviewIfNeeded()
                    }

                    if let titleText, !titleText.isEmpty {
                        self.previewOverlay = .title(text: titleText)
                    } else {
                        self.previewOverlay = .none
                    }

                    let titleIndex = titleDurationFrames - remaining
                    self.currentFrameIndex = max(0, titleIndex)
                    
                    let nextRemaining = remaining - 1
                    if nextRemaining > 0 {
                        phase = .title(remaining: nextRemaining)
                    } else {
                        self.previewOverlay = .none
                        phase = .frames
                        framesPhaseLocalIndex = 0
                    }
                    
                case .frames:
                    self.previewOverlay = .none

                    if !audioDidStart {
                        audioDidStart = true
                        self.startAudioPreviewIfNeeded()
                    }

                    self.currentFrameIndex = self.titleFrameCount + framesPhaseLocalIndex
                    
                    let nextLocal = framesPhaseLocalIndex + 1
                    if nextLocal < frames.count {
                        framesPhaseLocalIndex = nextLocal
                    } else {
                        self.stopAudioPreview()
                        if creditsDurationFrames > 0, let creditsText {
                            phase = .credits(remaining: creditsDurationFrames, total: creditsDurationFrames)
                            self.previewOverlay = .credits(text: creditsText, progress: 0)
                            creditsPhaseLocalIndex = 0
                        } else {
                            audioDidStart = false
                            phase = titleDurationFrames > 0 ? .title(remaining: titleDurationFrames) : .frames
                            framesPhaseLocalIndex = 0
                        }
                    }
                    
                case .credits(let remaining, let total):
                    if let creditsText, !creditsText.isEmpty {
                        let clampedTotal = max(total, 1)
                        let progress = min(1, max(0, 1.0 - (Double(remaining) / Double(clampedTotal))))
                        self.previewOverlay = .credits(text: creditsText, progress: progress)
                    } else {
                        self.previewOverlay = .none
                    }

                    let creditsStartIndex = self.titleFrameCount + frames.count
                    self.currentFrameIndex = creditsStartIndex + creditsPhaseLocalIndex
                    
                    let nextRemaining = remaining - 1
                    if nextRemaining > 0 {
                        phase = .credits(remaining: nextRemaining, total: total)
                        creditsPhaseLocalIndex += 1
                    } else {
                        self.previewOverlay = .none
                        audioDidStart = false
                        phase = titleDurationFrames > 0 ? .title(remaining: titleDurationFrames) : .frames
                        framesPhaseLocalIndex = 0
                    }
                }
                
                try? await Task.sleep(nanoseconds: nanosPerFrame)
            }
        }
    }

    private func stopAudioPreview() {
        audioStopTask?.cancel()
        audioStopTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func startAudioPreviewIfNeeded() {
        guard hasAudio, let fileName = project.audioFileName else { return }
        let start = audioSelectionStartSeconds
        let end = audioSelectionEndSeconds
        guard end > start else { return }

        audioStopTask?.cancel()
        audioStopTask = nil
        audioPlayer?.stop()
        audioPlayer = nil

        let playDuration = min(end - start, max(0, totalTimelineDurationSeconds))
        guard playDuration > 0 else { return }

        Task { [weak self] in
            guard let self else { return }
            let url = await MovieStorage.shared.audioFileURL(projectId: self.project.id, fileName: fileName)
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.currentTime = start
                let nanos = UInt64((playDuration * 1_000_000_000).rounded(.up))

                await MainActor.run {
                    self.audioPlayer = player
                    _ = self.audioPlayer?.play()

                    self.audioStopTask?.cancel()
                    self.audioStopTask = Task { [weak self] in
                        guard let self else { return }
                        try? await Task.sleep(nanoseconds: nanos)
                        await MainActor.run {
                            self.audioPlayer?.stop()
                            self.audioPlayer = nil
                        }
                    }
                }
            } catch {
                return
            }
        }
    }
    
    private func reorderFrames() {
        let frames = sortedFrames
        for (index, frame) in frames.enumerated() {
            frame.orderIndex = index
        }
        project.updatedAt = Date()
    }

    private func clampCurrentFrameIndex() {
        let total = totalFrameCount
        guard total > 0 else {
            currentFrameIndex = 0
            return
        }
        currentFrameIndex = min(max(currentFrameIndex, 0), total - 1)
    }
}

extension EditorViewModel {
    enum AudioImportError: LocalizedError {
        case notPlayable
        case noAudioTrack
        case tooShort

        var errorDescription: String? {
            switch self {
            case .notPlayable:
                return "Selected file is not playable."
            case .noAudioTrack:
                return "Selected file contains no audio track."
            case .tooShort:
                return "Selected audio is too short."
            }
        }
    }
}

private enum AudioWaveformExtractor {
    nonisolated static func extract(url: URL, fps: Int) throws -> [CGFloat] {
        let safeFPS = max(fps, 1)
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let totalFrames = Int(audioFile.length)

        guard totalFrames > 0, sampleRate > 0, channels > 0 else { return [] }

        let framesPerBin = max(1, Int(sampleRate / Double(safeFPS)))
        let binCount = max(1, Int(ceil(Double(totalFrames) / Double(framesPerBin))))
        var bins = [Float](repeating: 0, count: binCount)

        let bufferCapacity: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferCapacity) else {
            return []
        }

        var globalFrameOffset = 0
        while globalFrameOffset < totalFrames {
            let framesToRead = min(Int(bufferCapacity), totalFrames - globalFrameOffset)
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(framesToRead))

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { break }

            for i in 0..<framesRead {
                let absoluteFrameIndex = globalFrameOffset + i
                let binIndex = min(binCount - 1, absoluteFrameIndex / framesPerBin)

                var peak: Float = 0
                if let floatData = buffer.floatChannelData {
                    for ch in 0..<channels {
                        peak = max(peak, abs(floatData[ch][i]))
                    }
                } else if let int16Data = buffer.int16ChannelData {
                    let denom = Float(Int16.max)
                    for ch in 0..<channels {
                        peak = max(peak, abs(Float(int16Data[ch][i]) / denom))
                    }
                } else if let int32Data = buffer.int32ChannelData {
                    let denom = Float(Int32.max)
                    for ch in 0..<channels {
                        peak = max(peak, abs(Float(int32Data[ch][i]) / denom))
                    }
                }

                bins[binIndex] = max(bins[binIndex], peak)
            }

            globalFrameOffset += framesRead
        }

        let maxValue = bins.max() ?? 0
        guard maxValue > 0 else { return bins.map { _ in 0 } }

        return bins.map { CGFloat($0 / maxValue) }
    }
}

enum PreviewOverlay: Equatable {
    case none
    case title(text: String)
    case credits(text: String, progress: Double)
}

