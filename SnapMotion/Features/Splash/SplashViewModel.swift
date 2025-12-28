//
//  SplashViewModel.swift
//  Frame Director
//
//  Created by Cenk Alasonyalılar on 29.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import Foundation

@MainActor
@Observable
final class SplashViewModel {
    enum Phase: Equatable {
        case loading
        case ready
    }

    private let entitlementService: EntitlementService

    var phase: Phase = .loading

    private var hasStarted = false

    init(entitlementService: EntitlementService) {
        self.entitlementService = entitlementService
    }

    func start(minimumDurationRange: ClosedRange<Double> = 1.5...2.5) async {
        guard !hasStarted else { return }
        hasStarted = true

        let startedAt = Date()
        let minimumDurationSeconds = pickMinimumDuration(range: minimumDurationRange)

        entitlementService.configure()

        await waitForInitialEntitlementSync()
        await waitToMeetMinimumDuration(seconds: minimumDurationSeconds, startedAt: startedAt)
        phase = .ready
    }

    private func pickMinimumDuration(range: ClosedRange<Double>) -> Double {
        let lower = max(0, range.lowerBound)
        let upper = max(lower, range.upperBound)
        return Double.random(in: lower...upper)
    }

    private func waitForInitialEntitlementSync() async {
        while !entitlementService.hasCompletedInitialEntitlementSync {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func waitToMeetMinimumDuration(seconds: Double, startedAt: Date) async {
        let minimum = max(0, seconds)
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = max(0, minimum - elapsed)

        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }
}


