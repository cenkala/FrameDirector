//
//  FeatureGateService.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation

enum ProFeature {
    case videoExport
    case imageExport
    case structuredCredits
    case unlimitedProjects
    case deleteProjects
    case noTimeLimit
}

@Observable
final class FeatureGateService {
    static let shared = FeatureGateService()
    
    var isPro: Bool = false
    
    private init() {}
    
    func canAccess(_ feature: ProFeature) -> Bool {
        return isPro
    }
    
    func checkAccess(_ feature: ProFeature, onDenied: @escaping () -> Void) {
        if !canAccess(feature) {
            onDenied()
        }
    }
}

