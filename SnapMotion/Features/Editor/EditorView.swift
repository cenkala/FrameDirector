//
//  EditorView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData
import UIKit
import Photos

struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let project: MovieProject
    
    @Bindable var viewModel: EditorViewModel
    @State private var showCaptureView = false
    @State private var showImportView = false
    @State private var paywallPresenter = PaywallPresenter.shared
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var currentFrameImage: UIImage?
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.viewModel = EditorViewModel(project: project, modelContext: modelContext)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Metrics.contentSpacing) {
                previewSection
                controlsSection
                framesSection
            }
            .padding(AppTheme.Metrics.screenPadding)
            .padding(.bottom, 12)
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(viewModel.sortedFrames.isEmpty)

                Button {
                    handleExport()
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(!viewModel.canExport || isExporting)
                .proFeatureBadge(isLocked: !FeatureGateService.shared.isPro)

                Menu {
                    Button {
                        showCaptureView = true
                    } label: {
                        Label(LocalizedStringKey("create.camera"), systemImage: "camera")
                    }

                    Button {
                        showImportView = true
                    } label: {
                        Label(LocalizedStringKey("create.photoLibrary"), systemImage: "photo")
                    }

                    Button {
                        viewModel.showTitleCredits = true
                    } label: {
                        Label(LocalizedStringKey("editor.titleCredits"), systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
        .sheet(isPresented: $showCaptureView) {
            CaptureView(project: project)
        }
        .sheet(isPresented: $showImportView) {
            ImportView(project: project, modelContext: modelContext)
        }
        .sheet(isPresented: $paywallPresenter.shouldShowPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showTitleCredits) {
            TitleCreditsView(project: project, modelContext: modelContext)
        }
        .task(id: viewModel.currentFrameIndex) {
            await loadCurrentFrameImage()
        }
        .onChange(of: viewModel.sortedFrames.count) { _, _ in
            Task { await loadCurrentFrameImage() }
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
        .alert("Export Failed", isPresented: .constant(exportError != nil)) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Your video has been saved to Photos.")
        }
    }
    
    private var previewSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                }

            if viewModel.sortedFrames.isEmpty {
                ContentUnavailableView {
                    Label(LocalizedStringKey("editor.noFrames"), systemImage: "film.stack")
                }
            } else if let currentFrameImage {
                Image(uiImage: currentFrameImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .padding(10)
                    .overlay(alignment: .topLeading) {
                        AppChip(systemImage: "rectangle.stack", text: "\(viewModel.currentFrameIndex + 1)/\(viewModel.sortedFrames.count)")
                            .padding(12)
                    }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey("editor.fps"))
                    .font(.headline.weight(.semibold))
                Spacer()
                AppChip(systemImage: "clock", text: String(format: "%.1fs", project.duration))
            }

            Stepper(value: Binding(
                get: { project.fps },
                set: { viewModel.updateFPS($0) }
            ), in: 1...60) {
                HStack {
                    Text("\(project.fps)")
                        .font(.title3.weight(.bold))
                    Text("fps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.exceedsFreeDuration {
                Text(LocalizedStringKey("editor.freeLimit"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .appCard()
    }

    private var framesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("editor.frames"))
                    .font(.headline.weight(.semibold))
                Spacer()
                AppChip(systemImage: "photo.stack", text: "\(viewModel.sortedFrames.count)")
            }

            FrameStripView(
                frames: viewModel.sortedFrames,
                projectId: project.id,
                currentIndex: $viewModel.currentFrameIndex,
                onDelete: { index in
                    viewModel.deleteFrame(at: index)
                },
                onDuplicate: { index in
                    if viewModel.canAddMoreFrames() {
                        viewModel.duplicateFrame(at: index)
                    } else {
                        paywallPresenter.presentPaywall()
                    }
                },
                onMove: { source, destination in
                    viewModel.moveFrame(from: source, to: destination)
                }
            )
            .frame(height: 120)
            .padding(.horizontal, -AppTheme.Metrics.screenPadding)
            .padding(.bottom, -AppTheme.Metrics.screenPadding)
        }
        .appCard()
    }
    
    private func handleExport() {
        guard viewModel.canExport else { return }
        
        if !FeatureGateService.shared.canAccess(.videoExport) {
            paywallPresenter.presentPaywall()
            return
        }
        
        if viewModel.exceedsFreeDuration && !FeatureGateService.shared.isPro {
            paywallPresenter.presentPaywall()
            return
        }
        
        isExporting = true
        
        Task {
            do {
                let exportService = ExportService()
                let url = try await exportService.exportVideo(project: project)
                
                await MainActor.run {
                    project.exportedVideoURL = url.absoluteString
                    project.updatedAt = Date()
                    try? modelContext.save()
                }
                
                try await saveVideoToPhotos(url: url)
                
                await MainActor.run {
                    isExporting = false
                    showExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
    
    private func saveVideoToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized else {
            throw ExportError.photoLibraryAccessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
    
    enum ExportError: LocalizedError {
        case photoLibraryAccessDenied
        
        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return "Photos access is required to save the video. Please enable it in Settings."
            }
        }
    }
    
    @MainActor
    private func loadCurrentFrameImage() async {
        let frames = viewModel.sortedFrames
        guard !frames.isEmpty else {
            currentFrameImage = nil
            return
        }
        
        let safeIndex = min(max(viewModel.currentFrameIndex, 0), frames.count - 1)
        if safeIndex != viewModel.currentFrameIndex {
            viewModel.currentFrameIndex = safeIndex
        }
        
        let frame = frames[safeIndex]
        currentFrameImage = await MovieStorage.shared.loadFrame(fileName: frame.localFileName, projectId: project.id)
    }
}

