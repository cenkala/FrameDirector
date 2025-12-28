//
//  CaptureViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftUI
import SwiftData
import AVFoundation

@MainActor
@Observable
final class CaptureViewModel {
    private let cameraService = CameraCaptureService()
    private let project: MovieProject
    private let modelContext: ModelContext
    private let captureSessionId: String = UUID().uuidString
    private let targetStackId: String?
    
    var capturedImages: [UIImage] = []
    var isReady = false
    var errorMessage: String?
    var showGrid = false
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        cameraService.previewLayer
    }
    
    var flashMode: AVCaptureDevice.FlashMode {
        cameraService.flashMode
    }
    
    init(project: MovieProject, modelContext: ModelContext, targetStackId: String? = nil) {
        self.project = project
        self.modelContext = modelContext
        self.targetStackId = targetStackId
        setupCamera()
    }
    
    private func setupCamera() {
        cameraService.onPhotoCaptured = { [weak self] image in
            self?.handlePhotoCaptured(image)
        }
        
        cameraService.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
        
        Task {
            do {
                try await cameraService.setupSession()
                await MainActor.run {
                    isReady = true
                }
                cameraService.startSession()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func capturePhoto() {
        cameraService.capturePhoto()
    }
    
    func toggleFlash() {
        cameraService.toggleFlash()
    }
    
    func toggleGrid() {
        showGrid.toggle()
    }
    
    private func handlePhotoCaptured(_ image: UIImage) {
        capturedImages.append(image)
        
        Task {
            await saveFrame(image)
        }
    }
    
    private func saveFrame(_ image: UIImage) async {
        do {
            let fileName = "\(UUID().uuidString).jpg"
            _ = try await MovieStorage.shared.saveFrame(image, fileName: fileName, projectId: project.id)
            
            let effectiveStackId = targetStackId ?? captureSessionId
            let insertionOrderIndex = calculateInsertionOrderIndex(for: effectiveStackId)

            let frameAsset = FrameAsset(
                localFileName: fileName,
                orderIndex: insertionOrderIndex,
                source: .capture,
                stackId: effectiveStackId
            )
            
            frameAsset.project = project
            modelContext.insert(frameAsset)
            project.frames.append(frameAsset)
            normalizeFrameOrder()
            project.updatedAt = Date()
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calculateInsertionOrderIndex(for stackId: String) -> Int {
        // If the stack already exists, insert after the last frame of that stack.
        let existing = project.frames.filter { $0.stackId == stackId }
        if let maxOrder = existing.map(\.orderIndex).max() {
            return maxOrder + 1
        }
        return project.frames.count
    }

    private func normalizeFrameOrder() {
        let sorted = project.frames.sorted { $0.orderIndex < $1.orderIndex }
        for (index, frame) in sorted.enumerated() {
            frame.orderIndex = index
        }
    }
    
    func cleanup() {
        cameraService.stopSession()
    }
}

