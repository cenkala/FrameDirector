//
//  EntitlementService.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import RevenueCat

@MainActor
@Observable
final class EntitlementService: NSObject {
    static let shared = EntitlementService()
    
    private(set) var isPro: Bool = false
    private(set) var isConfigured: Bool = false
    private(set) var latestCustomerInfo: CustomerInfo?
    private(set) var lastCustomerInfoUpdate: Date?
    
    private let proEntitlementIdentifier = "pro"
    
    private override init() {
        super.init()
    }
    
    func configure() {
        guard !isConfigured else { return }
        
        #if DEBUG
        let apiKey = "test_ockQtixmiHMimpWdEquWGgBwAoG"
        #else
        let apiKey = "appl_msoSnomJtZvouslRgkiSuJWgoZX"
        #endif
        
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .debug
        
        isConfigured = true
        
        Task {
            await checkEntitlements()
        }
        
        setupPurchasesDelegate()
    }
    
    func checkEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateEntitlements(customerInfo: customerInfo)
        } catch {
            print("Failed to fetch customer info: \(error)")
        }
    }
    
    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateEntitlements(customerInfo: customerInfo)
    }
    
    func fetchAvailablePackages() async throws -> [Package] {
        let offerings = try await Purchases.shared.offerings()
        
        if let currentOffering = offerings.current {
            return currentOffering.availablePackages
        }
        
        if let firstOffering = offerings.all.values.first {
            return firstOffering.availablePackages
        }
        
        return []
    }
    
    func purchase(package: Package) async throws -> (customerInfo: CustomerInfo, userCancelled: Bool) {
        let result = try await Purchases.shared.purchase(package: package)
        updateEntitlements(customerInfo: result.customerInfo)
        return (result.customerInfo, result.userCancelled)
    }
    
    private func setupPurchasesDelegate() {
        Purchases.shared.delegate = self
    }
    
    private func updateEntitlements(customerInfo: CustomerInfo) {
        latestCustomerInfo = customerInfo
        lastCustomerInfoUpdate = Date()

        let proEntitlementActive = customerInfo.entitlements[proEntitlementIdentifier]?.isActive == true
        let hasActiveSubscription = !customerInfo.activeSubscriptions.isEmpty
        let hasAnyActiveEntitlement = !customerInfo.entitlements.active.isEmpty

        isPro = proEntitlementActive || hasActiveSubscription || hasAnyActiveEntitlement
        FeatureGateService.shared.isPro = isPro
    }

    var managementURL: URL? {
        latestCustomerInfo?.managementURL
    }

    var latestExpirationDate: Date? {
        latestCustomerInfo?.latestExpirationDate
    }

    var activeSubscriptionIdentifiers: [String] {
        Array(latestCustomerInfo?.activeSubscriptions ?? [])
            .sorted()
    }
}

extension EntitlementService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateEntitlements(customerInfo: customerInfo)
        }
    }
}

