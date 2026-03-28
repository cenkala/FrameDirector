//
//  ImportViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import FirebaseAnalytics

@Observable
final class ImportViewModel {
    private let project: MovieProject
    private let modelContext: ModelContext
    private let frameExtractor = FrameExtractor()
    private let targetStackId: String?
    
    var selectedItems: [PhotosPickerItem] = []
    var isProcessing = false
    var processingProgress: Double = 0.0
    var errorMessage: String?
    
    init(project: MovieProject, modelContext: ModelContext, targetStackId: String? = nil) {
        self.project = project
        self.modelContext = modelContext
        self.targetStackId = targetStackId
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
                let insertionOrderIndex = calculateInsertionOrderIndex(for: targetStackId)
                let frameAsset = FrameAsset(
                    localFileName: fileName,
                    orderIndex: insertionOrderIndex,
                    source: source,
                    stackId: targetStackId
                )
                
                frameAsset.project = project
                modelContext.insert(frameAsset)
                project.frames.append(frameAsset)
                normalizeFrameOrder()
                project.updatedAt = Date()
                try? modelContext.save()

                // Log Firebase Analytics event for photo library import
                Analytics.logEvent("content_photo_import", parameters: [
                    "project_id": project.id.uuidString,
                    "project_title": project.title,
                    "source": source.rawValue,
                    "idfv": IDFVManager.shared.getIDFV(),
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func calculateInsertionOrderIndex(for stackId: String?) -> Int {
        guard let stackId else { return project.frames.count }
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

