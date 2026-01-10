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

    var body: some View {
        RevenueCatUI.PaywallView()
            .tint(.accentColor)
            .onDisappear {
                paywallPresenter.dismissPaywall()
                Task { await EntitlementService.shared.checkEntitlements() }
            }
            .appScreenBackground()
    }
}
