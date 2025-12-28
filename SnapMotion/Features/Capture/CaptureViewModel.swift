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
    private var capturedFrameAssets: [FrameAsset] = []
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

    func deleteCapturedImage(at index: Int) async {
        guard index >= 0 && index < capturedImages.count && index < capturedFrameAssets.count else { return }

        let frameAsset = capturedFrameAssets[index]

        // Remove from arrays
        await MainActor.run {
            capturedImages.remove(at: index)
            capturedFrameAssets.remove(at: index)
        }

        // Delete physical file
        do {
            try await MovieStorage.shared.deleteFrameFile(fileName: frameAsset.localFileName, projectId: project.id)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete file: \(error.localizedDescription)"
            }
        }

        // Remove from database
        await MainActor.run {
            modelContext.delete(frameAsset)
            project.frames.removeAll { $0.id == frameAsset.id }
            normalizeFrameOrder()
            project.updatedAt = Date()

            do {
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handlePhotoCaptured(_ image: UIImage) {
        capturedImages.append(image)

        Task {
            let frameAsset = await saveFrame(image)
            if let frameAsset = frameAsset {
                capturedFrameAssets.append(frameAsset)
            }
        }
    }
    
    private func saveFrame(_ image: UIImage) async -> FrameAsset? {
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
            return frameAsset
        } catch {
            errorMessage = error.localizedDescription
            return nil
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

