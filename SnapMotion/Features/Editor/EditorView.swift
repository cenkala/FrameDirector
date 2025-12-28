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
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.background.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
            previewSection
                playControlsSection
                Spacer(minLength: 0)
            timelineSection
        }
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)
        .frame(maxHeight: .infinity)
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(
            LinearGradient(
                colors: [
                    AppTheme.Colors.elevatedSurface.opacity(0.8),
                    AppTheme.Colors.elevatedSurface.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigationBar
        )
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    handleExport()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 36, height: 36)

                    if isExporting {
                        ProgressView()
                                .tint(.blue)
                    } else {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .disabled(!viewModel.canExport || isExporting)
                .overlay(alignment: .topTrailing) {
                    if !FeatureGateService.shared.isPro {
                        ZStack {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 16, height: 16)
                            Text("PRO")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .offset(x: 6, y: -6)
                    }
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
            // Main container with enhanced styling
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Colors.elevatedSurface)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 12,
                    x: 0,
                    y: 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.separator.opacity(0.3),
                                    AppTheme.Colors.separator.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )

            if viewModel.sortedFrames.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.6))

                    Text(LocalizedStringKey("editor.noFrames"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Add frames to start creating your video")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            } else if let currentFrameImage {
                ZStack {
                Image(uiImage: currentFrameImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                        .cornerRadius(16)
                        .padding(2)

                    // Enhanced frame counter
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 80, height: 32)

                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.stack.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("\(viewModel.currentFrameIndex + 1)/\(viewModel.sortedFrames.count)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(16)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            } else {
                VStack(spacing: 16) {
                ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading frame...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .padding(.horizontal, 4)
    }

    private var playControlsSection: some View {
        HStack(spacing: 20) {
            // Left side - FPS Controls
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach([1, 5, 10, 15, 20, 24, 25, 30, 50, 60], id: \.self) { fps in
                            Button {
                                viewModel.updateFPS(fps)
                            } label: {
                                HStack {
                                    Text("\(fps)")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("FPS")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    if fps == project.fps {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(project.fps)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                                .monospacedDigit()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .frame(height: 32) // Fixed height for alignment
                }

                // Duration
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURATION")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .tracking(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fs", project.duration))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                    .frame(height: 20) // Fixed height for alignment
                }

                // Warning if needed
                if viewModel.exceedsFreeDuration {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .frame(height: 54) // Match total height of other elements
                }
            }

            Spacer()

            // Center - Play Button
            Button {
                viewModel.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isPlaying ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 2
                        )

                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(viewModel.isPlaying ? .red : Color.accentColor)
                }
            }
            .disabled(viewModel.sortedFrames.isEmpty)

            // Right side - Edit Menu
            Menu {
                Button {
                    viewModel.deleteFrame(at: viewModel.currentFrameIndex)
                } label: {
                    Label("Delete Frame", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .disabled(viewModel.sortedFrames.isEmpty)

                Button {
                    if viewModel.canAddMoreFrames() {
                        viewModel.duplicateFrame(at: viewModel.currentFrameIndex)
                    } else {
                        paywallPresenter.presentPaywall()
                    }
                } label: {
                    Label("Duplicate Frame", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.sortedFrames.isEmpty)

                Divider()

                Button {
                    viewModel.showTitleCredits = true
                } label: {
                    Label("Add Title/Credits", systemImage: "text.alignleft")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.sortedFrames.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.elevatedSurface)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 4)
    }

    private var timelineSection: some View {
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
        .frame(height: 100)
        .padding(.horizontal, 4)
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

