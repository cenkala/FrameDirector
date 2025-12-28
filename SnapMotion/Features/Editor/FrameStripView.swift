//
//  FrameStripView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct FrameStripView: View {
    let frames: [FrameAsset]
    let projectId: UUID
    @Binding var currentIndex: Int
    let onDelete: (Int) -> Void
    let onDuplicate: (Int) -> Void
    let onMove: (Int, Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                    FrameThumbnailView(
                        frame: frame,
                        projectId: projectId,
                        index: index,
                        isSelected: index == currentIndex,
                        onTap: {
                            currentIndex = index
                        },
                        onDelete: {
                            onDelete(index)
                        },
                        onDuplicate: {
                            onDuplicate(index)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

