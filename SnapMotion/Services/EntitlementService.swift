//
//  EntitlementService.swift
//  Frame Director
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
    private(set) var hasCompletedInitialEntitlementSync: Bool = false
    private(set) var latestCustomerInfo: CustomerInfo?
    private(set) var lastCustomerInfoUpdate: Date?
    
    private let proEntitlementIdentifier = "pro"
    
    private override init() {
        super.init()
    }
    
    func configure() {
        guard !isConfigured else { return }

        let apiKey = revenueCatAPIKey()
        Purchases.configure(withAPIKey: apiKey)

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        
        isConfigured = true
        
        Task {
            await checkEntitlements()
        }
        
        setupPurchasesDelegate()
    }
    
    func checkEntitlements() async {
        defer { hasCompletedInitialEntitlementSync = true }
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

    private func revenueCatAPIKey() -> String {
        #if DEBUG
        let infoPlistKey = "RevenueCatAPIKeyDebug"
        let environmentKey = "REVENUECAT_API_KEY_DEBUG"
        #else
        let infoPlistKey = "RevenueCatAPIKeyRelease"
        let environmentKey = "REVENUECAT_API_KEY_RELEASE"
        #endif

        let rawValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String
        let infoPlistValue = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !infoPlistValue.isEmpty { return infoPlistValue }

        let environmentValue = (ProcessInfo.processInfo.environment[environmentKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !environmentValue.isEmpty { return environmentValue }

        #if DEBUG
        print("RevenueCat API key not found in Info.plist (\(infoPlistKey)) or environment (\(environmentKey)). Falling back to test key for DEBUG.")
        return "test_ockQtixmiHMimpWdEquWGgBwAoG"
        #else
        preconditionFailure("Missing or empty RevenueCat API key. Expected Info.plist key: \(infoPlistKey) (or environment: \(environmentKey)).")
        #endif
    }
}

extension EntitlementService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateEntitlements(customerInfo: customerInfo)
        }
    }
}

