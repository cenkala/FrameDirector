//
//  EditorViewModel.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

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
    case singleFrame(FrameAsset)

    var id: String {
        switch self {
        case .singleFrame(let frame):
            return frame.id.uuidString
        }
    }

    var frames: [FrameAsset] {
        switch self {
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

    private var playbackTask: Task<Void, Never>?

    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
        self.featureGate = FeatureGateService.shared
    }
    
    var sortedFrames: [FrameAsset] {
        project.frames.sorted { $0.orderIndex < $1.orderIndex }
    }

    var timelineItems: [TimelineItem] {
        let frames = sortedFrames
        // Tüm frameleri tek tek göster, stack yapısını kullanma
        return frames.map { .singleFrame($0) }
    }

    var totalFrameCount: Int {
        timelineItems.reduce(0) { $0 + $1.frames.count }
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
        currentFrameIndex = globalIndex
    }

    func getGlobalFrameIndex(for frame: FrameAsset) -> Int {
        let frames = sortedFrames
        return frames.firstIndex(where: { $0.id == frame.id }) ?? 0
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
    
    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }
    
    private func startPlayback() {
        guard project.fps > 0, !sortedFrames.isEmpty else { return }
        
        isPlaying = true
        playbackTask?.cancel()
        
        playbackTask = Task { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                let frames = self.sortedFrames
                if frames.isEmpty {
                    self.stopPlayback()
                    return
                }
                
                let nextIndex = (self.currentFrameIndex + 1) % max(frames.count, 1)
                self.currentFrameIndex = nextIndex
                
                let nanosPerFrame = UInt64(1_000_000_000 / max(self.project.fps, 1))
                try? await Task.sleep(nanoseconds: nanosPerFrame)
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
}

