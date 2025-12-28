//
//  FrameAsset.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

enum FrameSource: String, Codable {
    case capture
    case photoImport
    case videoExtract
}

@Model
final class FrameAsset {
    var id: UUID
    var localFileName: String
    var captureDate: Date
    var orderIndex: Int
    var source: String
    
    var project: MovieProject?
    
    init(
        id: UUID = UUID(),
        localFileName: String,
        captureDate: Date = Date(),
        orderIndex: Int,
        source: FrameSource
    ) {
        self.id = id
        self.localFileName = localFileName
        self.captureDate = captureDate
        self.orderIndex = orderIndex
        self.source = source.rawValue
    }
    
    var sourceEnum: FrameSource {
        get { FrameSource(rawValue: source) ?? .capture }
        set { source = newValue.rawValue }
    }
}

