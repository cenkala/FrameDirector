//
//  PaywallView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import RevenueCatUI

struct PaywallView: View {
    @State private var paywallPresenter = PaywallPresenter.shared
    @State private var entitlementService = EntitlementService.shared

    var body: some View {
        RevenueCatUI.PaywallView()
            .tint(.accentColor)
            .onChange(of: entitlementService.isPro) { _, isPro in
                guard isPro else { return }
                paywallPresenter.dismissPaywall()
            }
            .onDisappear {
                paywallPresenter.dismissPaywall()
                Task { await EntitlementService.shared.checkEntitlements() }
            }
            .appScreenBackground()
    }
}
