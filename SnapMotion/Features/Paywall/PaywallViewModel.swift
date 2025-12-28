//
//  PaywallViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import RevenueCat

@MainActor
@Observable
final class PaywallViewModel {
    private let entitlementService: EntitlementService
    
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var packages: [Package] = []
    var selectedPackageIdentifier: String?
    var errorMessage: String?
    
    init(entitlementService: EntitlementService) {
        self.entitlementService = entitlementService
    }
    
    var selectedPackage: Package? {
        guard let selectedPackageIdentifier else { return nil }
        return packages.first(where: { $0.identifier == selectedPackageIdentifier })
    }
    
    func load() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let packages = try await entitlementService.fetchAvailablePackages()
            self.packages = packages
            selectedPackageIdentifier = selectedPackageIdentifier ?? packages.first?.identifier
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func select(package: Package) {
        selectedPackageIdentifier = package.identifier
    }
    
    func purchaseSelectedPackage() async throws -> Bool {
        guard let selectedPackage else { return false }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        let result = try await entitlementService.purchase(package: selectedPackage)
        return !result.userCancelled
    }
    
    func restore() async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        
        try await entitlementService.restorePurchases()
    }
}


