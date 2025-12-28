//
//  MovieStorage.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import UIKit

actor MovieStorage {
    static let shared = MovieStorage()
    
    private let documentsDirectory: URL
    private let moviesDirectory: URL
    
    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        moviesDirectory = documentsDirectory.appendingPathComponent("Movies")
        
        Task {
            try? FileManager.default.createDirectory(at: moviesDirectory, withIntermediateDirectories: true)
        }
    }
    
    func projectDirectory(for projectId: UUID) -> URL {
        moviesDirectory.appendingPathComponent(projectId.uuidString)
    }
    
    func createProjectDirectory(for projectId: UUID) throws {
        let dir = projectDirectory(for: projectId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    func saveFrame(_ image: UIImage, fileName: String, projectId: UUID) throws -> URL {
        let projectDir = projectDirectory(for: projectId)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        let fileURL = projectDir.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw StorageError.compressionFailed
        }
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    func loadFrame(fileName: String, projectId: UUID) -> UIImage? {
        let fileURL = projectDirectory(for: projectId).appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func duplicateFrameFile(from sourceFileName: String, to destinationFileName: String, projectId: UUID) throws -> URL {
        let projectDir = projectDirectory(for: projectId)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        let sourceURL = projectDir.appendingPathComponent(sourceFileName)
        let destinationURL = projectDir.appendingPathComponent(destinationFileName)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    func deleteFrameFile(fileName: String, projectId: UUID) throws {
        let fileURL = projectDirectory(for: projectId).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
    
    func saveExportedVideo(_ url: URL, projectId: UUID) throws -> URL {
        let projectDir = projectDirectory(for: projectId)
        let destination = projectDir.appendingPathComponent("export.mp4")
        
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
    
    func deleteProject(projectId: UUID) throws {
        let projectDir = projectDirectory(for: projectId)
        try FileManager.default.removeItem(at: projectDir)
    }
    
    enum StorageError: LocalizedError {
        case compressionFailed
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "Failed to compress image"
            case .saveFailed:
                return "Failed to save file"
            }
        }
    }
}

