//
//  CaptureViewModel.swift
//  SnapMotion
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
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
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
            
            let frameAsset = FrameAsset(
                localFileName: fileName,
                orderIndex: project.frames.count,
                source: .capture
            )
            
            frameAsset.project = project
            modelContext.insert(frameAsset)
            project.frames.append(frameAsset)
            project.updatedAt = Date()
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func cleanup() {
        cameraService.stopSession()
    }
}

