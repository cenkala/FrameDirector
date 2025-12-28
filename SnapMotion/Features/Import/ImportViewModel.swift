//
//  ImportViewModel.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData

@Observable
final class ImportViewModel {
    private let project: MovieProject
    private let modelContext: ModelContext
    private let frameExtractor = FrameExtractor()
    
    var selectedItems: [PhotosPickerItem] = []
    var isProcessing = false
    var processingProgress: Double = 0.0
    var errorMessage: String?
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
    }
    
    func processSelectedItems() async {
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
        }
        
        let itemCount = selectedItems.count
        
        for (index, item) in selectedItems.enumerated() {
            if let result = try? await item.loadTransferable(type: Data.self) {
                if let image = UIImage(data: result) {
                    await saveImageFrame(image, source: .photoImport)
                }
            } else if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
                await processVideo(movie.url)
            }
            
            await MainActor.run {
                processingProgress = Double(index + 1) / Double(itemCount)
            }
        }
        
        await MainActor.run {
            isProcessing = false
            selectedItems = []
        }
    }
    
    private func processVideo(_ url: URL) async {
        do {
            let frames = try await frameExtractor.extractFrames(from: url, fps: project.fps)
            
            for frame in frames {
                await saveImageFrame(frame, source: .videoExtract)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveImageFrame(_ image: UIImage, source: FrameSource) async {
        do {
            let fileName = "\(UUID().uuidString).jpg"
            _ = try await MovieStorage.shared.saveFrame(image, fileName: fileName, projectId: project.id)
            
            await MainActor.run {
                let frameAsset = FrameAsset(
                    localFileName: fileName,
                    orderIndex: project.frames.count,
                    source: source
                )
                
                frameAsset.project = project
                modelContext.insert(frameAsset)
                project.frames.append(frameAsset)
                project.updatedAt = Date()
                try? modelContext.save()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

