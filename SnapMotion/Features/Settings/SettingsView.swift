//
//  SettingsView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var languageManager = LanguageManager.shared
    @State private var entitlementService = EntitlementService.shared
    @State private var isRestoringPurchases = false
    @State private var isRefreshingEntitlements = false
    
    var body: some View {
        NavigationStack {
            List {
                membershipSection

                Section {
                    Picker(selection: $languageManager.currentLanguage) {
                        ForEach(SupportedLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    } label: {
                        Text(LocalizedStringKey("settings.language"))
                    }
                }
                
                Section {
                    Button {
                        Task {
                            isRestoringPurchases = true
                            do {
                                try await entitlementService.restorePurchases()
                            } catch {
                                print("Failed to restore purchases: \(error)")
                            }
                            isRestoringPurchases = false
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey("settings.restorePurchases"))
                            if isRestoringPurchases {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)
                }
                
                Section {
                    HStack {
                        Text(LocalizedStringKey("settings.version"))
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .appFormBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.done"))
                    }
                }
            }
        }
        .tint(.accentColor)
    }

    private var membershipSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LocalizedStringKey("settings.membership"))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    membershipBadge
                }

                if let expiration = entitlementService.latestExpirationDate {
                    HStack {
                        Text(LocalizedStringKey("settings.membership.expires"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(expiration, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if let managementURL = entitlementService.managementURL {
                    Button {
                        openURL(managementURL)
                    } label: {
                        Text(LocalizedStringKey("settings.membership.manage"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }

                Button {
                    Task {
                        isRefreshingEntitlements = true
                        await entitlementService.checkEntitlements()
                        isRefreshingEntitlements = false
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey("settings.membership.refresh"))
                            .frame(maxWidth: .infinity)
                        if isRefreshingEntitlements {
                            ProgressView()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .disabled(isRefreshingEntitlements)
            }
            .appCard(isElevated: false)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var membershipBadge: some View {
        if entitlementService.isPro {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.caption.weight(.semibold))
                Text(LocalizedStringKey("settings.membership.pro"))
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .systemYellow))
            )
        } else {
            AppChip(systemImage: "person.fill", textKey: LocalizedStringKey("settings.membership.free"))
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

