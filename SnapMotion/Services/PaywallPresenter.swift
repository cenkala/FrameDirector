//
//  PaywallPresenter.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

@Observable
final class PaywallPresenter {
    static let shared = PaywallPresenter()
    
    private let hasShownInitialPaywallKey = "hasShownInitialPaywall"
    
    var shouldShowPaywall: Bool = false
    
    var hasShownInitialPaywall: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasShownInitialPaywallKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasShownInitialPaywallKey)
        }
    }
    
    private init() {}
    
    func showPaywallIfNeeded() {
        guard !EntitlementService.shared.isPro else { return }
        guard !hasShownInitialPaywall else { return }
        shouldShowPaywall = true
    }
    
    func presentPaywall() {
        guard !EntitlementService.shared.isPro else { return }
        shouldShowPaywall = true
    }
    
    func dismissPaywall() {
        shouldShowPaywall = false
        if !hasShownInitialPaywall {
            hasShownInitialPaywall = true
        }
    }
}

