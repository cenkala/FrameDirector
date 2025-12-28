//
//  FrameAsset.swift
//  Frame Director
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
    /// Frames with the same `stackId` and adjacent order will be shown as a single stack item in the timeline.
    /// For camera captures this is set to the current capture session id.
    var stackId: String?
    
    var project: MovieProject?
    
    init(
        id: UUID = UUID(),
        localFileName: String,
        captureDate: Date = Date(),
        orderIndex: Int,
        source: FrameSource,
        stackId: String? = nil
    ) {
        self.id = id
        self.localFileName = localFileName
        self.captureDate = captureDate
        self.orderIndex = orderIndex
        self.source = source.rawValue
        self.stackId = stackId
    }
    
    var sourceEnum: FrameSource {
        get { FrameSource(rawValue: source) ?? .capture }
        set { source = newValue.rawValue }
    }
}

