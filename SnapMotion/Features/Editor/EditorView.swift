//
//  EditorView.swift
//  Frame Director
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
    @State private var showExportOptions = false
    @State private var showExportSavedAlert = false
    @State private var currentFrameImage: UIImage?
    @State private var exportShareURL: URL?
    @State private var showShareSheet = false
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
            
            VStack(spacing: 0) {
                previewSection
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                    .padding(.bottom, 10)
                
                playControlsSection
                
                timelineSection
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                
                Spacer(minLength: 0)
            }
            .padding(.top, 0)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            
            if isExporting {
                exportHUD
                    .transition(.opacity)
            }
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
                    handleExportButtonTap()
                } label: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
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
                .confirmationDialog(
                    LocalizedStringKey("editor.export"),
                    isPresented: $showExportOptions,
                    titleVisibility: .visible
                ) {
                    Button(LocalizedStringKey("general.save")) {
                        startExport(action: .save)
                    }
                    Button(LocalizedStringKey("player.share")) {
                        startExport(action: .share)
                    }
                    Button(LocalizedStringKey("general.cancel"), role: .cancel) { }
                } message: {
                    Text(LocalizedStringKey("editor.exportOptions.message"))
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
        .sheet(isPresented: $showCaptureView) {
            CaptureView(
                project: project,
                targetStackId: nil,
                lastFrameImage: currentFrameImage
            )
        }
        .sheet(isPresented: $showImportView) {
            ImportView(project: project, modelContext: modelContext, targetStackId: nil)
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
        .alert(
            LocalizedStringKey("error.exportFailed"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { isPresented in
                    if !isPresented {
                        exportError = nil
                    }
                }
            )
        ) {
            Button(LocalizedStringKey("general.ok"), role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "")
        }
        .alert(
            LocalizedStringKey("editor.exportSaved.title"),
            isPresented: $showExportSavedAlert
        ) {
            Button(LocalizedStringKey("general.ok"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("editor.exportSaved.message"))
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportShareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private var previewSection: some View {
        ZStack {
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
                    
                    PreviewTitleCreditsOverlay(overlay: viewModel.previewOverlay)
                        .allowsHitTesting(false)
                    
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
        .frame(maxHeight: .infinity)
    }
    
    private var playControlsSection: some View {
        let controlCircleSize: CGFloat = 48

        return HStack(spacing: 12) {
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
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                                .monospacedDigit()
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .frame(height: 30) // Fixed height for alignment
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURATION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .tracking(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fs", project.duration))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                    .frame(height: 18) // Fixed height for alignment
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
                        .frame(width: controlCircleSize, height: controlCircleSize)
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                    
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
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
                        .frame(width: controlCircleSize, height: controlCircleSize)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.sortedFrames.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
    }
    
    private var timelineSection: some View {
        let titleText = project.titleCardText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let creditsText = ExportService.buildCreditsText(project: project) ?? ""
        let hasTitle = !titleText.isEmpty
        let hasCredits = !creditsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return HStack(spacing: 8) {
            if hasTitle {
                TimelineAuxChip(
                    title: "TITLE",
                    systemImage: "textformat",
                    action: { viewModel.showTitleCardPreview() }
                )
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
                onAddCamera: {
                    showCaptureView = true
                },
                onAddPhotoLibrary: {
                    showImportView = true
                },
                onAddTitleCredits: {
                    viewModel.showTitleCredits = true
                },
                onSelectFrame: { index in
                    viewModel.selectFrame(at: index)
                },
                getGlobalIndex: { frame in
                    viewModel.getGlobalFrameIndex(for: frame)
                }
            )
            .frame(height: 100)
            
            if hasCredits {
                TimelineAuxChip(
                    title: "CREDITS",
                    systemImage: "list.bullet",
                    action: { viewModel.showCreditsPreview() }
                )
            }
        }
    }
    
    private enum ExportAction {
        case save
        case share
    }
    
    private var exportHUD: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)
                
                Text(LocalizedStringKey("editor.exporting"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.75))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
        }
        .animation(.easeInOut(duration: 0.15), value: isExporting)
    }
    
    private func handleExportButtonTap() {
        guard viewModel.canExport else { return }
        
        if !FeatureGateService.shared.canAccess(.videoExport) {
            paywallPresenter.presentPaywall()
            return
        }
        
        if viewModel.exceedsFreeDuration && !FeatureGateService.shared.isPro {
            paywallPresenter.presentPaywall()
            return
        }
        
        showExportOptions = true
    }
    
    private func startExport(action: ExportAction) {
        guard viewModel.canExport else { return }
        guard !isExporting else { return }
        
        isExporting = true
        exportError = nil
        exportShareURL = nil
        
        Task {
            do {
                let exportService = ExportService()
                let url = try await exportService.exportVideo(project: project)
                
                await MainActor.run {
                    project.exportedVideoURL = url.absoluteString
                    project.updatedAt = Date()
                    try? modelContext.save()
                    exportShareURL = url
                }
                
                switch action {
                case .save:
                    try await saveVideoToPhotos(url: url)
                    await MainActor.run {
                        isExporting = false
                        showExportSavedAlert = true
                    }
                case .share:
                    await MainActor.run {
                        isExporting = false
                        showShareSheet = true
                    }
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct PreviewTitleCreditsOverlay: View {
    let overlay: PreviewOverlay
    
    @State private var creditsTextHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            switch overlay {
            case .none:
                EmptyView()
                
            case .title(let text):
                ZStack {
                    Color.black.opacity(0.92)
                    
                    Text(text)
                        .font(.system(size: max(26, min(54, geo.size.height * 0.06)), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal, max(20, geo.size.width * 0.08))
                        .padding(.vertical, max(16, geo.size.height * 0.08))
                }
                
            case .credits(let text, let progress):
                ZStack {
                    Color.black.opacity(0.92)
                    
                    creditsView(text: text, in: geo.size, progress: progress)
                        .clipped()
                        .padding(.horizontal, max(18, geo.size.width * 0.08))
                }
            }
        }
    }
    
    @ViewBuilder
    private func creditsView(text: String, in size: CGSize, progress: Double) -> some View {
        let paddingY = max(18, size.height * 0.08)
        let startY = size.height - paddingY
        let endY = -creditsTextHeight - paddingY
        let y = startY + CGFloat(min(1, max(0, progress))) * (endY - startY)
        
        Text(text)
            .font(.system(size: max(20, min(44, size.height * 0.05)), weight: .regular, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(max(6, size.height * 0.01))
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { creditsTextHeight = g.size.height }
                        .onChange(of: g.size.height) { _, newValue in
                            creditsTextHeight = newValue
                        }
                }
            )
            .offset(y: y)
    }
}

private struct TimelineAuxChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.8)
            }
            .frame(width: 62, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

