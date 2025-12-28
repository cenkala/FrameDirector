//
//  HomeViewModel.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import SwiftData

@Observable
final class HomeViewModel {
    private let modelContext: ModelContext
    private let featureGate: FeatureGateService
    
    var projects: [MovieProject] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.featureGate = FeatureGateService.shared
        loadProjects()
    }
    
    func loadProjects() {
        let descriptor = FetchDescriptor<MovieProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        projects = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func canCreateProject() -> Bool {
        return ProjectLimits.canCreateProject(
            currentProjectCount: projects.count,
            isPro: featureGate.isPro
        )
    }
    
    func createProject(title: String) -> MovieProject {
        let project = MovieProject(title: title)
        modelContext.insert(project)
        try? modelContext.save()
        loadProjects()
        return project
    }
    
    func deleteProject(_ project: MovieProject) {
        guard project.canDelete(isPro: featureGate.isPro) else { return }
        modelContext.delete(project)
        try? modelContext.save()
        loadProjects()
    }
    
    func canDeleteProject(_ project: MovieProject) -> Bool {
        return project.canDelete(isPro: featureGate.isPro)
    }
}

