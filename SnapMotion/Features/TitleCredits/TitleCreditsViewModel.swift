//
//  TitleCreditsViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

nonisolated struct ExtraCreditField: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var label: String
    var value: String
    
    init(id: UUID = UUID(), label: String = "", value: String = "") {
        self.id = id
        self.label = label
        self.value = value
    }
}

nonisolated struct StructuredCredits: Codable, Sendable {
    var director: String = ""
    var animator: String = ""
    var music: String = ""
    var thanks: String = ""
    var extras: [ExtraCreditField] = []
    
    init(
        director: String = "",
        animator: String = "",
        music: String = "",
        thanks: String = "",
        extras: [ExtraCreditField] = []
    ) {
        self.director = director
        self.animator = animator
        self.music = music
        self.thanks = thanks
        self.extras = extras
    }
    
    private enum CodingKeys: String, CodingKey {
        case director
        case animator
        case music
        case thanks
        case extras
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.director = try container.decodeIfPresent(String.self, forKey: .director) ?? ""
        self.animator = try container.decodeIfPresent(String.self, forKey: .animator) ?? ""
        self.music = try container.decodeIfPresent(String.self, forKey: .music) ?? ""
        self.thanks = try container.decodeIfPresent(String.self, forKey: .thanks) ?? ""
        self.extras = try container.decodeIfPresent([ExtraCreditField].self, forKey: .extras) ?? []
    }
}

@Observable
final class TitleCreditsViewModel {
    let project: MovieProject
    private let modelContext: ModelContext
    private let featureGate: FeatureGateService
    
    var titleText: String
    var plainCredits: String
    var structuredCredits: StructuredCredits
    var selectedMode: CreditsMode
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.modelContext = modelContext
        self.featureGate = FeatureGateService.shared
        
        self.titleText = project.titleCardText ?? ""
        self.plainCredits = project.plainCreditsText ?? ""
        self.selectedMode = project.creditsModeEnum
        
        if let jsonString = project.structuredCreditsJSON,
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(StructuredCredits.self, from: data) {
            self.structuredCredits = decoded
        } else {
            self.structuredCredits = StructuredCredits()
        }
    }
    
    var canUseStructured: Bool {
        featureGate.isPro
    }
    
    func save() {
        project.titleCardText = titleText.isEmpty ? nil : titleText
        project.creditsModeEnum = selectedMode
        
        switch selectedMode {
        case .plain:
            project.plainCreditsText = plainCredits.isEmpty ? nil : plainCredits
            project.structuredCreditsJSON = nil
        case .structured:
            if let data = try? JSONEncoder().encode(structuredCredits),
               let jsonString = String(data: data, encoding: .utf8) {
                project.structuredCreditsJSON = jsonString
            }
            project.plainCreditsText = nil
        }
        
        project.updatedAt = Date()
        try? modelContext.save()
    }
}

