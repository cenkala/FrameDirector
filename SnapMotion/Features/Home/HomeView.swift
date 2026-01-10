//
//  HomeView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var paywallPresenter = PaywallPresenter.shared
    @State private var showCreateProjectAlert = false
    @State private var newProjectTitle = ""
    @State private var showSettings = false
    @State private var selectedProject: MovieProject?
    @State private var showEditor = false
    @State private var showPlayer = false
    @State private var hasScheduledInitialPaywallPresentation = false
    @State private var shouldPresentPaywallAfterSettingsDismiss = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    homeContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                guard shouldPresentPaywallAfterSettingsDismiss else { return }
                shouldPresentPaywallAfterSettingsDismiss = false
                
                DispatchQueue.main.async {
                    paywallPresenter.presentPaywall()
                }
            }) {
                SettingsView(onUpgradeToPro: {
                    shouldPresentPaywallAfterSettingsDismiss = true
                })
            }
            .sheet(isPresented: $paywallPresenter.shouldShowPaywall) {
                PaywallView()
            }
            .alert(LocalizedStringKey("create.title"), isPresented: $showCreateProjectAlert) {
                TextField(LocalizedStringKey("create.projectName"), text: $newProjectTitle)
                
                Button {
                    showCreateProjectAlert = false
                } label: {
                    Text(LocalizedStringKey("general.cancel"))
                }
                
                Button {
                    createProjectFromAlert()
                } label: {
                    Text(LocalizedStringKey("general.done"))
                }
                .disabled(newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationDestination(isPresented: $showEditor) {
                if let project = selectedProject {
                    EditorView(project: project, modelContext: modelContext)
                }
            }
            .navigationDestination(isPresented: $showPlayer) {
                if let project = selectedProject {
                    PlayerView(project: project)
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
        .onAppear {
            if viewModel == nil {
                viewModel = HomeViewModel(modelContext: modelContext)
            }
            viewModel?.loadProjects()
            
            if !hasScheduledInitialPaywallPresentation {
                hasScheduledInitialPaywallPresentation = true
                DispatchQueue.main.async {
                    paywallPresenter.showPaywallIfNeeded()
                }
            }
        }
        .onChange(of: showSettings) { _, isPresented in
            guard !isPresented else { return }
            guard shouldPresentPaywallAfterSettingsDismiss else { return }
            // Presentation is handled in the sheet's onDismiss to ensure the Settings sheet is fully gone.
        }
        .onChange(of: showEditor) { _, isPresented in
            if !isPresented {
                viewModel?.loadProjects()
            }
        }
        .onChange(of: showPlayer) { _, isPresented in
            if !isPresented {
                viewModel?.loadProjects()
            }
        }
        .onChange(of: paywallPresenter.shouldShowPaywall) { _, isPresented in
            if !isPresented {
                Task { await EntitlementService.shared.checkEntitlements() }
                viewModel?.loadProjects()
            }
        }
    }
    
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.contentSpacing) {
                headerBranding
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 6)
                
                createButton(isProLocked: !viewModel.canCreateProject())
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                
                projectsSection(viewModel: viewModel)
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.bottom, 24)
            }
        }
    }
    
    private func projectsSection(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("home.myProjects"))
                .font(.headline.weight(.semibold))
            
            if viewModel.projects.isEmpty {
                Text(LocalizedStringKey("home.noSavedProjects"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.projects, id: \.id) { project in
                        ProjectCardView(
                            project: project,
                            onPlay: {
                                selectedProject = project
                                showPlayer = true
                            },
                            onEdit: {
                                selectedProject = project
                                showEditor = true
                            },
                            onDelete: {
                                viewModel.deleteProject(project)
                            },
                            onRequestDeleteUpgrade: {
                                paywallPresenter.presentPaywall()
                            },
                            canDelete: viewModel.canDeleteProject(project)
                        )
                    }
                }
            }
        }
    }
    
    private var headerBranding: some View {
        VStack(spacing: 10) {
            Image("ic_app_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                }

            Text(LocalizedStringKey("app.name"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func createButton(isProLocked: Bool) -> some View {
        Button {
            handleCreateProject()
        } label: {
            Label(LocalizedStringKey("home.createStopMotion"), systemImage: "plus")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle)
        .tint(.accentColor)
        .controlSize(.large)
        .proFeatureBadge(isLocked: isProLocked)
    }
    
    private func handleCreateProject() {
        guard let viewModel = viewModel else { return }
        
        if viewModel.canCreateProject() {
            newProjectTitle = ""
            showCreateProjectAlert = true
        } else {
            paywallPresenter.presentPaywall()
        }
    }
    
    private func createProjectFromAlert() {
        guard let viewModel = viewModel else { return }
        
        let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        let project = viewModel.createProject(title: title)
        selectedProject = project
        showEditor = true
    }
}

