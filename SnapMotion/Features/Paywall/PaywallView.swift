//
//  PaywallView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var paywallPresenter = PaywallPresenter.shared
    @State private var viewModel: PaywallViewModel?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Metrics.contentSpacing) {
                    headerSection
                    featuresSection
                    packagesSection
                    footerSection
                }
                .padding(AppTheme.Metrics.screenPadding)
                .padding(.bottom, 100)
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
            .navigationTitle(LocalizedStringKey("paywall.subscribe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        paywallPresenter.dismissPaywall()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
        .task {
            if viewModel == nil {
                viewModel = await MainActor.run {
                    PaywallViewModel(entitlementService: EntitlementService.shared)
                }
            }
            await viewModel?.load()
        }
        .onDisappear {
            paywallPresenter.dismissPaywall()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("ic_app_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                }

            HStack(spacing: 6) {
                Text(LocalizedStringKey("paywall.hero.beforePro"))
                    .font(.title3.weight(.semibold))

                Text("PRO")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .systemYellow))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(LocalizedStringKey("paywall.hero.afterPro"))
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)

            Button {
                Purchases.shared.presentCodeRedemptionSheet()
            } label: {
                Text(LocalizedStringKey("paywall.redeemCode"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "infinity", title: LocalizedStringKey("paywall.feature.unlimitedProjects"))
            FeatureRow(icon: "clock", title: LocalizedStringKey("paywall.feature.noTimeLimit"))
            FeatureRow(icon: "video", title: LocalizedStringKey("paywall.feature.videoExport"))
            FeatureRow(icon: "photo", title: LocalizedStringKey("paywall.feature.imageExport"))
            FeatureRow(icon: "list.bullet.rectangle", title: LocalizedStringKey("paywall.feature.structuredCredits"))
            FeatureRow(icon: "trash", title: LocalizedStringKey("paywall.feature.deleteProjects"))
        }
        .appCard()
    }
    
    private var packagesSection: some View {
        VStack(spacing: 16) {
            if viewModel == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let viewModel, viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let viewModel, let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Text(LocalizedStringKey("general.retry"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
                .appCard()
            } else if let viewModel, viewModel.packages.isEmpty {
                VStack(spacing: 12) {
                    Text(LocalizedStringKey("paywall.noPackages"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Text(LocalizedStringKey("general.retry"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
                .appCard()
            } else if let viewModel {
                VStack(spacing: 12) {
                    ForEach(viewModel.packages, id: \.identifier) { package in
                        packageRow(package: package)
                    }
                }
            }
        }
    }
    
    private func packageRow(package: Package) -> some View {
        let isSelected = viewModel?.selectedPackageIdentifier == package.identifier
        let description = package.storeProduct.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDescription = !description.isEmpty
        
        return Button {
            viewModel?.select(package: package)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.35), lineWidth: 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if hasDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(package.storeProduct.localizedPriceString)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.surface : AppTheme.Colors.elevatedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.separator.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel?.isPurchasing == true)
    }
    
    private var footerSection: some View {
        HStack(spacing: 20) {
            Link(destination: URL(string: "https://example.com/terms")!) {
                Text(LocalizedStringKey("paywall.termsOfService"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://example.com/privacy")!) {
                Text(LocalizedStringKey("paywall.privacyPolicy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if let viewModel, let selectedPackage = viewModel.selectedPackage {
                HStack {
                    Text(selectedPackage.storeProduct.localizedTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(selectedPackage.storeProduct.localizedPriceString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    guard let viewModel else { return }
                    do {
                        let purchased = try await viewModel.purchaseSelectedPackage()
                        guard purchased else { return }
                        await EntitlementService.shared.checkEntitlements()
                        paywallPresenter.dismissPaywall()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Text(LocalizedStringKey("paywall.subscribe"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .disabled(viewModel?.selectedPackage == nil || viewModel?.isPurchasing == true)

            Button {
                Task {
                    guard let viewModel else { return }
                    do {
                        try await viewModel.restore()
                        if FeatureGateService.shared.isPro {
                            paywallPresenter.dismissPaywall()
                            dismiss()
                        }
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Text(LocalizedStringKey("paywall.restore"))
                    .font(.subheadline)
            }
            .disabled(viewModel?.isPurchasing == true)
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Colors.separator.opacity(0.25))
                .frame(height: 1)
        }
    }
}

