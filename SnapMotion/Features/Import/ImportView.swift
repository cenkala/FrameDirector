//
//  ImportView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    let project: MovieProject
    
    @Bindable var viewModel: ImportViewModel
    
    init(project: MovieProject, modelContext: ModelContext) {
        self.project = project
        self.viewModel = ImportViewModel(project: project, modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isProcessing {
                    processingView
                } else {
                    pickerView
                }
            }
            .padding()
            .navigationTitle(LocalizedStringKey("import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.cancel"))
                    }
                }
                
                if !viewModel.selectedItems.isEmpty && !viewModel.isProcessing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await viewModel.processSelectedItems()
                                dismiss()
                            }
                        } label: {
                            Text(LocalizedStringKey("general.done"))
                        }
                    }
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
    }
    
    private var pickerView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Metrics.contentSpacing) {
            AppSectionHeader(LocalizedStringKey("import.title"), subtitle: LocalizedStringKey("import.selectPhotos"))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AppIconBadge(systemImage: "photo.on.rectangle.angled")

                    Text(LocalizedStringKey("import.selectPhotos"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(
                    selection: $viewModel.selectedItems,
                    maxSelectionCount: 100,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label(LocalizedStringKey("import.selectPhotos"), systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                if !viewModel.selectedItems.isEmpty {
                    AppChip(systemImage: "checkmark.circle", text: "\(viewModel.selectedItems.count)")
                }
            }
            .appCard()

            Spacer()
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.processingProgress) {
                Text(LocalizedStringKey("import.processing"))
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            
            Text(String(format: "%.0f%%", viewModel.processingProgress * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

