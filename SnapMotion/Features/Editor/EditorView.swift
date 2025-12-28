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
    @State private var showAddDialog = false
    @State private var pendingAddStackId: String? = nil
    @State private var endPlusStackId: String? = nil
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.viewModel = EditorViewModel(project: project, modelContext: modelContext)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            previewSection
            controlsSection
            Spacer()
            timelineSection
        }
        .padding(AppTheme.Metrics.screenPadding)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity)
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
                        pendingAddStackId = nil
                        showCaptureView = true
                    } label: {
                        Label(LocalizedStringKey("create.camera"), systemImage: "camera")
                    }

                    Button {
                        pendingAddStackId = nil
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
            CaptureView(project: project, targetStackId: pendingAddStackId)
        }
        .sheet(isPresented: $showImportView) {
            ImportView(project: project, modelContext: modelContext, targetStackId: pendingAddStackId)
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
        .confirmationDialog("Add", isPresented: $showAddDialog, titleVisibility: .hidden) {
            Button {
                showCaptureView = true
            } label: {
                Text(LocalizedStringKey("create.camera"))
            }

            Button {
                showImportView = true
            } label: {
                Text(LocalizedStringKey("create.photoLibrary"))
            }

            Button {
                viewModel.showTitleCredits = true
            } label: {
                Text(LocalizedStringKey("editor.titleCredits"))
            }

            Button(role: .cancel) {
                pendingAddStackId = nil
            } label: {
                Text(LocalizedStringKey("general.cancel"))
            }
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
        .frame(height: 240)
    }
    
    private var controlsSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // FPS Controls
            HStack(spacing: 8) {
                Text("FPS:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Button {
                        if project.fps > 1 {
                            viewModel.updateFPS(project.fps - 1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Text("\(project.fps)")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 30)
                        .foregroundColor(.accentColor)

                    Button {
                        if project.fps < 60 {
                            viewModel.updateFPS(project.fps + 1)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }

            Spacer()

            // Duration info
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1fs", project.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Warning if needed
            if viewModel.exceedsFreeDuration {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.Colors.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey("editor.frames"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.totalFrameCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            TimelineView(
                timelineItems: viewModel.timelineItems,
                projectId: project.id,
                currentFrameIndex: $viewModel.currentFrameIndex,
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
                onMoveFrame: { source, destination in
                    viewModel.moveFrame(from: source, to: destination)
                },
                onMoveTimelineItem: { sourceItemIndex, destinationItemIndex in
                    viewModel.moveTimelineItem(from: sourceItemIndex, to: destinationItemIndex)
                },
                onSetStackId: { frameId, stackId in
                    // No-op since we don't use stackId anymore
                },
                onMoveFrameById: { frameId, destinationIndex in
                    viewModel.moveFrameById(frameId, toGlobalIndex: destinationIndex)
                },
                onTapAddToStack: { stackId in
                    // No-op since we don't use stacks anymore
                },
                onTapAddToEnd: {
                    showAddDialog = true
                },
                onSelectFrame: { index in
                    viewModel.selectFrame(at: index)
                },
                getGlobalIndex: { frame in
                    viewModel.getGlobalFrameIndex(for: frame)
                }
            )
            .frame(maxHeight: 120)
            .listRowInsets(EdgeInsets(top: .zero, leading: 10, bottom: .zero, trailing: .zero))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.Colors.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                )
        )
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

