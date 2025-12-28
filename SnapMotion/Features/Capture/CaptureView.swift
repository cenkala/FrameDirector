//
//  CaptureView.swift
//  SnapMotion
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
    
    @State private var viewModel: CaptureViewModel?
    
    var body: some View {
        ZStack {
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
                cameraPreview(previewLayer: previewLayer, showGrid: viewModel.showGrid)
            } else {
                ProgressView()
            }
            
            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .padding()
        }
        .ignoresSafeArea()
        .tint(.accentColor)
        .onAppear {
            if viewModel == nil {
                viewModel = CaptureViewModel(project: project, modelContext: modelContext, targetStackId: targetStackId)
            }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }
    
    private func cameraPreview(previewLayer: AVCaptureVideoPreviewLayer, showGrid: Bool) -> some View {
        ZStack {
            CameraPreviewView(previewLayer: previewLayer)
            
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
        HStack(spacing: 12) {
            if let viewModel = viewModel, !viewModel.capturedImages.isEmpty {
                thumbnail(for: viewModel.capturedImages.last!)
            } else {
                Color.clear
                    .frame(width: 52, height: 52)
            }

            Spacer()

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

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(LocalizedStringKey("capture.done"))
                    .frame(width: 90)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
    
    private func thumbnail(for image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            )
    }
    
    private func flashIcon(for mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
}

