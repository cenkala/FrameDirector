//
//  TimelineView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Foundation

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum TimelineUI {
    static let frameSize: CGFloat = 72
    static let frameInnerSize: CGFloat = 66
    static let spacing: CGFloat = 6
    static let centerStrokeWidth: CGFloat = 3
    static let endPlusAreaWidth: CGFloat = 600
}

struct TimelineItemDropDelegate: DropDelegate {
    let targetIndex: Int
    let timelineItems: [TimelineItem]
    @Binding var draggedTimelineItemId: String?
    let onMoveTimelineItem: (Int, Int) -> Void
    @Binding var dropIndicatorIndex: Int?

    func dropEntered(info: DropInfo) {
        dropIndicatorIndex = targetIndex

        guard let draggedId = draggedTimelineItemId,
              let fromIndex = timelineItems.firstIndex(where: { $0.id == draggedId })
        else { return }

        guard fromIndex != targetIndex else { return }
        onMoveTimelineItem(fromIndex, targetIndex)
    }

    func dropExited(info: DropInfo) {
        dropIndicatorIndex = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropIndicatorIndex = targetIndex
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dropIndicatorIndex = nil
        draggedTimelineItemId = nil
        return true
    }
}

struct TimelineCombinedDropDelegate: DropDelegate {
    let targetItem: TimelineItem
    let targetIndexInTimeline: Int
    let timelineItems: [TimelineItem]
    @Binding var draggedTimelineItemId: String?
    @Binding var draggedFrameId: UUID?
    let onMoveTimelineItem: (Int, Int) -> Void
    let onSetStackId: (UUID, String?) -> Void
    let onMoveFrameById: (UUID, Int) -> Void
    @Binding var dropIndicatorIndex: Int?

    func dropEntered(info: DropInfo) {
        dropIndicatorIndex = targetIndexInTimeline

        if let draggedId = draggedTimelineItemId,
           let fromIndex = timelineItems.firstIndex(where: { $0.id == draggedId }),
           fromIndex != targetIndexInTimeline
        {
            onMoveTimelineItem(fromIndex, targetIndexInTimeline)
        }
    }

    func dropExited(info: DropInfo) {
        dropIndicatorIndex = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropIndicatorIndex = targetIndexInTimeline
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropIndicatorIndex = nil
            draggedTimelineItemId = nil
            draggedFrameId = nil
        }

        // Frame drag
        if let frameId = draggedFrameId {
            let targetStartIndex = timelineItems.prefix(targetIndexInTimeline).reduce(0) { $0 + $1.frames.count }

            switch targetItem {
            case .singleFrame:
                onSetStackId(frameId, nil)
                onMoveFrameById(frameId, targetStartIndex)
                return true
            }
        }

        // Timeline item drag
        if draggedTimelineItemId != nil {
            return true
        }

        return false
    }
}


struct TimelineView: View {
    let timelineItems: [TimelineItem]
    let projectId: UUID
    @Binding var currentFrameIndex: Int
    let onDelete: (Int) -> Void
    let onDuplicate: (Int) -> Void
    let onMoveFrame: (Int, Int) -> Void
    let onMoveTimelineItem: (Int, Int) -> Void
    let onSetStackId: (UUID, String?) -> Void
    let onMoveFrameById: (UUID, Int) -> Void
    let onTapAddToStack: (String) -> Void
    let onAddCamera: () -> Void
    let onAddPhotoLibrary: () -> Void
    let onAddTitleCredits: () -> Void
    let onSelectFrame: (Int) -> Void
    let getGlobalIndex: (FrameAsset) -> Int

    @State private var draggedTimelineItemId: String?
    @State private var draggedFrameId: UUID?
    @State private var dropIndicatorIndex: Int? = nil
    @State private var scrollPosition: UUID?
    @State private var isUserScrolling = false


    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if #available(iOS 17.0, *) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: TimelineUI.spacing) {
                            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                                if dropIndicatorIndex == index {
                                    // Drop indicator
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentColor)
                                        .frame(width: 3, height: 100)
                                        .transition(.scale)
                                        .zIndex(1)
                                }

                                TimelineItemView(
                                    item: item,
                                    projectId: projectId,
                                    currentFrameIndex: $currentFrameIndex,
                                    onDelete: onDelete,
                                    onDuplicate: onDuplicate,
                                    onMoveFrame: onMoveFrame,
                                    onMoveTimelineItem: onMoveTimelineItem,
                                    onSetStackId: onSetStackId,
                                    onMoveFrameById: onMoveFrameById,
                                    onTapAddToStack: onTapAddToStack,
                                    onSelectFrame: onSelectFrame,
                                    getGlobalIndex: getGlobalIndex,
                                    draggedTimelineItemId: $draggedTimelineItemId,
                                    draggedFrameId: $draggedFrameId,
                                    dropIndicatorIndex: $dropIndicatorIndex,
                                    timelineItems: timelineItems,
                                    indexInTimeline: index,
                                    geometry: geometry
                                )
                                .zIndex((draggedTimelineItemId == item.id) ? 2 : 1)
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1.0 : 0.8)
                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                                }
                            }

                            if dropIndicatorIndex == timelineItems.count {
                                // Drop indicator at the end
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor)
                                    .frame(width: 3, height: 100)
                                    .transition(.scale)
                                    .zIndex(1)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 2)
                        .animation(.spring(response: 0.3), value: dropIndicatorIndex)
                    }
                    .contentMargins(.horizontal, (geometry.size.width - TimelineUI.frameSize) / 2, for: .scrollContent)
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollTargetBehavior(.viewAligned)
                    .onChange(of: scrollPosition) { oldValue, newValue in
                        guard let frameId = newValue else { return }
                        // Find the frame with this ID
                        var frameCount = 0
                        for item in timelineItems {
                            for frame in item.frames {
                                if frame.id == frameId {
                                    if currentFrameIndex != frameCount {
                                        currentFrameIndex = frameCount
                                    }
                                    return
                                }
                                frameCount += 1
                            }
                        }
                    }
                    .onChange(of: currentFrameIndex) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        // Find frame by index and update scroll position
                        var frameCount = 0
                        for item in timelineItems {
                            for frame in item.frames {
                                if frameCount == newValue {
                                    if scrollPosition != frame.id {
                                        scrollPosition = frame.id
                                    }
                                    return
                                }
                                frameCount += 1
                            }
                        }
                    }
                    .onAppear {
                        if let firstFrame = timelineItems.first?.frames.first {
                            scrollPosition = firstFrame.id
                        }
                    }
                } else {
                    // iOS < 17 fallback: free scroll (no snapping)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TimelineUI.spacing) {
                            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                                TimelineItemView(
                                    item: item,
                                    projectId: projectId,
                                    currentFrameIndex: $currentFrameIndex,
                                    onDelete: onDelete,
                                    onDuplicate: onDuplicate,
                                    onMoveFrame: onMoveFrame,
                                    onMoveTimelineItem: onMoveTimelineItem,
                                    onSetStackId: onSetStackId,
                                    onMoveFrameById: onMoveFrameById,
                                    onTapAddToStack: onTapAddToStack,
                                    onSelectFrame: onSelectFrame,
                                    getGlobalIndex: getGlobalIndex,
                                    draggedTimelineItemId: $draggedTimelineItemId,
                                    draggedFrameId: $draggedFrameId,
                                    dropIndicatorIndex: $dropIndicatorIndex,
                                    timelineItems: timelineItems,
                                    indexInTimeline: index,
                                    geometry: geometry
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Fixed center selection frame
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.blue, lineWidth: TimelineUI.centerStrokeWidth)
                    .frame(width: TimelineUI.frameSize + 10, height: TimelineUI.frameSize + 10)
                    .position(x: geometry.size.width / 2, y: 60)
                    .allowsHitTesting(false)
                
                // Plus button at trailing edge
                HStack {
                    Spacer()
                    Menu {
                        Button {
                            onAddCamera()
                        } label: {
                            Label(LocalizedStringKey("create.camera"), systemImage: "camera")
                        }

                        Button {
                            onAddPhotoLibrary()
                        } label: {
                            Label(LocalizedStringKey("create.photoLibrary"), systemImage: "photo.on.rectangle")
                        }

                        Button {
                            onAddTitleCredits()
                        } label: {
                            Label(LocalizedStringKey("editor.titleCredits"), systemImage: "text.alignleft")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(true)
            }
        }
        .frame(height: 120)
        .clipped() // Prevent vertical scrolling
    }
}

struct TimelineLooseDropDelegate: DropDelegate {
    let timelineItems: [TimelineItem]
    @Binding var draggedFrameId: UUID?
    let onSetStackId: (UUID, String?) -> Void
    let onMoveFrameById: (UUID, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedFrameId = nil }
        guard let frameId = draggedFrameId else { return false }

        // Drop on empty timeline: unstack and move to end.
        onSetStackId(frameId, nil)
        let totalFrames = timelineItems.reduce(0) { $0 + $1.frames.count }
        onMoveFrameById(frameId, max(0, totalFrames - 1))
        return true
    }
}

struct TimelineItemView: View {
    let item: TimelineItem
    let projectId: UUID
    @Binding var currentFrameIndex: Int
    let onDelete: (Int) -> Void
    let onDuplicate: (Int) -> Void
    let onMoveFrame: (Int, Int) -> Void
    let onMoveTimelineItem: (Int, Int) -> Void
    let onSetStackId: (UUID, String?) -> Void
    let onMoveFrameById: (UUID, Int) -> Void
    let onTapAddToStack: (String) -> Void
    let onSelectFrame: (Int) -> Void
    let getGlobalIndex: (FrameAsset) -> Int
    @Binding var draggedTimelineItemId: String?
    @Binding var draggedFrameId: UUID?
    @Binding var dropIndicatorIndex: Int?
    let timelineItems: [TimelineItem]
    let indexInTimeline: Int
    let geometry: GeometryProxy

    private func isFrameSelected(_ frame: FrameAsset) -> Bool {
        let globalIndex = getGlobalIndex(frame)
        return globalIndex == currentFrameIndex
    }

    private var isBeingDragged: Bool {
        draggedTimelineItemId == item.id
    }

    var body: some View {
        switch item {
        case .singleFrame(let frame):
            SingleFrameView(
                frame: frame,
                projectId: projectId,
                isSelected: isFrameSelected(frame),
                onDelete: onDelete,
                onDuplicate: onDuplicate,
                onSelect: { onSelectFrame(getGlobalIndex(frame)) }
            )
            .id(frame.id)
            .opacity(isBeingDragged ? 0.3 : 1.0)
            .scaleEffect(isBeingDragged ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBeingDragged)
            .onDrag {
                draggedFrameId = nil
                draggedTimelineItemId = item.id
                return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(of: [.text], delegate: TimelineCombinedDropDelegate(
                targetItem: item,
                targetIndexInTimeline: indexInTimeline,
                timelineItems: timelineItems,
                draggedTimelineItemId: $draggedTimelineItemId,
                draggedFrameId: $draggedFrameId,
                onMoveTimelineItem: onMoveTimelineItem,
                onSetStackId: onSetStackId,
                onMoveFrameById: onMoveFrameById,
                dropIndicatorIndex: $dropIndicatorIndex
            ))
        }
    }
}

struct SingleFrameView: View {
    let frame: FrameAsset
    let projectId: UUID
    let isSelected: Bool
    let onDelete: (Int) -> Void
    let onDuplicate: (Int) -> Void
    let onSelect: () -> Void

    var body: some View {
        TimelineThumbnailView(frame: frame, projectId: projectId, isSelected: isSelected)
            .frame(width: TimelineUI.frameSize, height: TimelineUI.frameSize)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(alignment: .topLeading) {
                if frame.sourceEnum == .videoExtract {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .offset(x: -4, y: -4)
                }
            }
            .onTapGesture {
                onSelect()
            }
    }
}


struct TimelineThumbnailView: View {
    let frame: FrameAsset
    let projectId: UUID
    let isSelected: Bool

    @State private var thumbnailImage: UIImage?

    var body: some View {
        ZStack {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Color.gray.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    )
            }

            // Selection indicator removed
        }
        .task(id: frame.localFileName) {
            thumbnailImage = await MovieStorage.shared.loadFrame(fileName: frame.localFileName, projectId: projectId)
        }
    }
}
