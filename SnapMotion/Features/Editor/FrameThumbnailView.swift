//
//  FrameThumbnailView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import UIKit

struct FrameThumbnailView: View {
    let frame: FrameAsset
    let projectId: UUID
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.elevatedSurface)
                    .frame(width: 80, height: 80)
                
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? AppTheme.Colors.accent : Color.clear, lineWidth: 3)
            )
            .contextMenu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(LocalizedStringKey("editor.deleteFrame"), systemImage: "trash")
                }
                
                Button {
                    onDuplicate()
                } label: {
                    Label(LocalizedStringKey("editor.duplicateFrame"), systemImage: "doc.on.doc")
                }
            }
            .onTapGesture {
                onTap()
            }
            .task(id: frame.localFileName) {
                thumbnailImage = await MovieStorage.shared.loadFrame(fileName: frame.localFileName, projectId: projectId)
            }
            
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

