//
//  TitleCreditsView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData

struct TitleCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    let project: MovieProject
    
    @Bindable var viewModel: TitleCreditsViewModel
    @State private var paywallPresenter = PaywallPresenter.shared
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.viewModel = TitleCreditsViewModel(project: project, modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                titleSection
                creditsModeSection
                creditsContentSection
            }
            .navigationTitle(LocalizedStringKey("titleCredits.title"))
            .navigationBarTitleDisplayMode(.inline)
            .appFormBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.cancel"))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.save()
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.save"))
                    }
                }
            }
            .sheet(isPresented: $paywallPresenter.shouldShowPaywall) {
                PaywallView()
            }
        }
        .tint(.accentColor)
    }
    
    private var titleSection: some View {
        Section {
            TextField(
                LocalizedStringKey("titleCredits.titlePlaceholder"),
                text: $viewModel.titleText,
                axis: .vertical
            )
            .lineLimit(3...6)
        } header: {
            Text(LocalizedStringKey("titleCredits.titleCard"))
        } footer: {
            Text("Optional: Leave empty to skip title card")
                .font(.caption)
        }
    }
    
    private var creditsModeSection: some View {
        Section {
            Picker(selection: $viewModel.selectedMode) {
                Text(LocalizedStringKey("titleCredits.plainCredits"))
                    .tag(CreditsMode.plain)
                
                HStack {
                    Text(LocalizedStringKey("titleCredits.structuredCredits"))
                    if !viewModel.canUseStructured {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .tag(CreditsMode.structured)
            } label: {
                Text(LocalizedStringKey("titleCredits.creditsMode"))
            }
            .onChange(of: viewModel.selectedMode) { _, newValue in
                if newValue == .structured && !viewModel.canUseStructured {
                    viewModel.selectedMode = .plain
                    paywallPresenter.presentPaywall()
                }
            }
        } header: {
            Text(LocalizedStringKey("titleCredits.credits"))
        }
    }
    
    private var creditsContentSection: some View {
        Section {
            switch viewModel.selectedMode {
            case .plain:
                PlainCreditsEditor(text: $viewModel.plainCredits)
            case .structured:
                if viewModel.canUseStructured {
                    StructuredCreditsEditor(credits: $viewModel.structuredCredits)
                } else {
                    Text("Structured credits are a Pro feature")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        } footer: {
            Text("Optional: Leave empty to skip credits")
                .font(.caption)
        }
    }
}

