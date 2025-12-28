//
//  TitleCreditsViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

struct StructuredCredits: Codable, Sendable {
    var director: String = ""
    var animator: String = ""
    var music: String = ""
    var thanks: String = ""
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

