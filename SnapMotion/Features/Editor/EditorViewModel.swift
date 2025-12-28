//
//  EditorViewModel.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

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
            source: originalFrame.sourceEnum
        )
        newFrame.project = project
        project.frames.append(newFrame)
        reorderFrames()
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

