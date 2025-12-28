//
//  CaptureView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData
import AVFoundation

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let project: MovieProject
    let targetStackId: String?
    let lastFrameImage: UIImage?
    
    @State private var viewModel: CaptureViewModel?
    @State private var overlayImage: UIImage?
    @AppStorage("showOverlay") private var showOverlay: Bool = true
    @State private var toastMessage: String?
    @State private var showToast = false
    
    var body: some View {
        ZStack {
            // Toast overlay
            if showToast, let message = toastMessage {
                VStack {
                    Text(message)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                        )
                    Spacer()
                }
                .padding(.top, 100)
                .transition(.opacity)
                .zIndex(1)
            }

            if let viewModel = viewModel, let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.close"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let viewModel = viewModel, viewModel.isReady, let previewLayer = viewModel.previewLayer {
                cameraPreview(
                    previewLayer: previewLayer,
                    showGrid: viewModel.showGrid,
                    overlayImage: overlayImage ?? lastFrameImage
                )
            } else {
                ProgressView()
            }

            HStack {
                if let viewModel = viewModel, !viewModel.capturedImages.isEmpty {
                    capturedImagesList(viewModel: viewModel)
                }
                Spacer()
            }
            .padding(.leading, 16)

            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom)
        }
        .ignoresSafeArea()
        .tint(.accentColor)
        .onAppear {
            if viewModel == nil {
                viewModel = CaptureViewModel(project: project, modelContext: modelContext, targetStackId: targetStackId)
            }
            if overlayImage == nil {
                overlayImage = lastFrameImage
            }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
        .onChange(of: viewModel?.capturedImages.count) { oldValue, newValue in
            // Update overlay to the last captured image when the count changes
            overlayImage = viewModel?.capturedImages.last ?? lastFrameImage
        }
    }
    
    private func cameraPreview(previewLayer: AVCaptureVideoPreviewLayer, showGrid: Bool, overlayImage: UIImage?) -> some View {
        CameraPreviewView(previewLayer: previewLayer)
            .overlay {
                if showOverlay, let overlayImage {
                    Image(uiImage: overlayImage)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .opacity(0.35)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if showGrid {
                    GridOverlay()
                }
            }
    }
    
    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            if let viewModel = viewModel {
                Button {
                    showOverlay.toggle()
                    showToastMessage(showOverlay ? "Referans görüntü açıldı" : "Referans görüntü kapatıldı")
                } label: {
                    Image(systemName: showOverlay ? "eye" : "eye.slash")
                        .font(.title2)
                        .foregroundStyle(
                            showOverlay
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(Color.white)
                        )
                        .padding()
                        .background(Circle().fill(.ultraThinMaterial))
                }

                Button {
                    viewModel.toggleFlash()
                } label: {
                    Image(systemName: flashIcon(for: viewModel.flashMode))
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Circle().fill(.ultraThinMaterial))
                }

                Button {
                    viewModel.toggleGrid()
                } label: {
                    Image(systemName: "grid")
                        .font(.title2)
                        .foregroundStyle(
                            viewModel.showGrid
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(Color.white)
                        )
                        .padding()
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
    }
    
    private var bottomControls: some View {
        Button {
            viewModel?.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 76, height: 76)
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 34)
    }
    
    
    private func flashIcon(for mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        // Hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    private func capturedImagesList(viewModel: CaptureViewModel) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(viewModel.capturedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        index == viewModel.capturedImages.count - 1
                                            ? Color.blue.opacity(0.8)
                                            : Color.white.opacity(0.7),
                                        lineWidth: index == viewModel.capturedImages.count - 1 ? 2 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Button {
                            Task {
                                await viewModel.deleteCapturedImage(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, .red.opacity(0.8))
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .offset(x: 4, y: -8)
                    }
                    .frame(width: 68, height: 68)
                }
            }
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 60)
        .padding(.bottom, 120)
        .frame(maxHeight: .infinity)
    }
}

