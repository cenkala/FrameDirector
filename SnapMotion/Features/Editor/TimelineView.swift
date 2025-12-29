//
//  TimelineView.swift
//  Frame Director
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

struct TimelineMetrics: Equatable {
    let frameSize: CGFloat
    let spacing: CGFloat
    let centerStrokeWidth: CGFloat
    let rowHeight: CGFloat
    let plusButtonSize: CGFloat

    static let regular = TimelineMetrics(
        frameSize: 72,
        spacing: 6,
        centerStrokeWidth: 3,
        rowHeight: 120,
        plusButtonSize: 36
    )

    static let compact = TimelineMetrics(
        frameSize: 48,
        spacing: 5,
        centerStrokeWidth: 2,
        rowHeight: 70,
        plusButtonSize: 32
    )
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
            default:
                return false
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
    @Binding var scrollPosition: Int?
    let scrollAnchorX: CGFloat
    let metrics: TimelineMetrics
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
    let onAddAudio: () -> Void
    let onSelectFrame: (Int) -> Void
    let getGlobalIndex: (FrameAsset) -> Int

    @State private var draggedTimelineItemId: String?
    @State private var draggedFrameId: UUID?
    @State private var dropIndicatorIndex: Int? = nil
    @State private var isUserScrolling = false

    init(
        timelineItems: [TimelineItem],
        projectId: UUID,
        currentFrameIndex: Binding<Int>,
        scrollPosition: Binding<Int?>,
        scrollAnchorX: CGFloat = 0.5,
        metrics: TimelineMetrics = .regular,
        onDelete: @escaping (Int) -> Void,
        onDuplicate: @escaping (Int) -> Void,
        onMoveFrame: @escaping (Int, Int) -> Void,
        onMoveTimelineItem: @escaping (Int, Int) -> Void,
        onSetStackId: @escaping (UUID, String?) -> Void,
        onMoveFrameById: @escaping (UUID, Int) -> Void,
        onTapAddToStack: @escaping (String) -> Void,
        onAddCamera: @escaping () -> Void,
        onAddPhotoLibrary: @escaping () -> Void,
        onAddTitleCredits: @escaping () -> Void,
        onAddAudio: @escaping () -> Void = { },
        onSelectFrame: @escaping (Int) -> Void,
        getGlobalIndex: @escaping (FrameAsset) -> Int
    ) {
        self.timelineItems = timelineItems
        self.projectId = projectId
        self._currentFrameIndex = currentFrameIndex
        self._scrollPosition = scrollPosition
        self.scrollAnchorX = scrollAnchorX
        self.metrics = metrics
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMoveFrame = onMoveFrame
        self.onMoveTimelineItem = onMoveTimelineItem
        self.onSetStackId = onSetStackId
        self.onMoveFrameById = onMoveFrameById
        self.onTapAddToStack = onTapAddToStack
        self.onAddCamera = onAddCamera
        self.onAddPhotoLibrary = onAddPhotoLibrary
        self.onAddTitleCredits = onAddTitleCredits
        self.onAddAudio = onAddAudio
        self.onSelectFrame = onSelectFrame
        self.getGlobalIndex = getGlobalIndex
    }


    var body: some View {
        GeometryReader { geometry in
            ZStack {
                timelineScrollView(in: geometry)
                playheadOverlay(in: geometry)
                plusMenuOverlay
            }
        }
        .frame(height: metrics.rowHeight)
        .clipped()
    }

    private func playheadOverlay(in geometry: GeometryProxy) -> some View {
        let clampedX = min(max(0, scrollAnchorX), 1)
        let x = geometry.size.width * clampedX
        let y = metrics.rowHeight / 2

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.blue, lineWidth: metrics.centerStrokeWidth)
            .frame(width: metrics.frameSize + 10, height: metrics.frameSize + 10)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func timelineScrollView(in geometry: GeometryProxy) -> some View {
        if #available(iOS 17.0, *) {
            let anchor = UnitPoint(x: min(max(0, scrollAnchorX), 1), y: 0.5)
            let sideInset = max(0, (geometry.size.width - metrics.frameSize) / 2)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: metrics.spacing) {
                    timelineItemsContent(in: geometry)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 2)
                .animation(.spring(response: 0.3), value: dropIndicatorIndex)
            }
            .contentMargins(.horizontal, sideInset, for: .scrollContent)
            .scrollPosition(id: $scrollPosition, anchor: anchor)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: scrollPosition) { _, newValue in
                guard let index = newValue else { return }
                if currentFrameIndex != index {
                    currentFrameIndex = index
                }
            }
            .onChange(of: currentFrameIndex) { oldValue, newValue in
                guard oldValue != newValue else { return }
                if scrollPosition != newValue {
                    scrollPosition = newValue
                }
            }
            .onAppear {
                if scrollPosition == nil {
                    scrollPosition = min(max(currentFrameIndex, 0), max(timelineItems.count - 1, 0))
                }
            }
        } else {
            let sideInset = max(0, (geometry.size.width - metrics.frameSize) / 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.spacing) {
                    timelineItemsContent(in: geometry)
                }
                .padding(.horizontal, sideInset + 2)
            }
        }
    }

    @ViewBuilder
    private func timelineItemsContent(in geometry: GeometryProxy) -> some View {
        let indexedItems = Array(timelineItems.enumerated())

        ForEach(indexedItems, id: \.element.id) { index, item in
            if dropIndicatorIndex == index {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: metrics.rowHeight)
                    .transition(.scale)
                    .zIndex(1)
            }

            TimelineItemView(
                item: item,
                projectId: projectId,
                currentFrameIndex: $currentFrameIndex,
                metrics: metrics,
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
            .id(index)
            .zIndex((draggedTimelineItemId == item.id) ? 2 : 1)
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1.0 : 0.8)
                    .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
            }
        }

        if dropIndicatorIndex == timelineItems.count {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3, height: metrics.rowHeight)
                .transition(.scale)
                .zIndex(1)
        }
    }

    private var plusMenuOverlay: some View {
        HStack {
            Spacer()
            Menu {
                Button(action: onAddCamera) {
                    Label(LocalizedStringKey("create.camera"), systemImage: "camera")
                }

                Button(action: onAddPhotoLibrary) {
                    Label(LocalizedStringKey("create.photoLibrary"), systemImage: "photo.on.rectangle")
                }

                Button(action: onAddTitleCredits) {
                    Label(LocalizedStringKey("editor.titleCredits"), systemImage: "text.alignleft")
                }

                // TODO: ca - uncomment this after sound timeline fixes
//                Button(action: onAddAudio) {
//                    Label(LocalizedStringKey("editor.addAudio"), systemImage: "waveform")
//                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: metrics.plusButtonSize, height: metrics.plusButtonSize)
                    .background(Circle().fill(Color.accentColor))
            }
            .menuStyle(.borderlessButton)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .allowsHitTesting(true)
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
    let metrics: TimelineMetrics
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

    init(
        item: TimelineItem,
        projectId: UUID,
        currentFrameIndex: Binding<Int>,
        metrics: TimelineMetrics = .regular,
        onDelete: @escaping (Int) -> Void,
        onDuplicate: @escaping (Int) -> Void,
        onMoveFrame: @escaping (Int, Int) -> Void,
        onMoveTimelineItem: @escaping (Int, Int) -> Void,
        onSetStackId: @escaping (UUID, String?) -> Void,
        onMoveFrameById: @escaping (UUID, Int) -> Void,
        onTapAddToStack: @escaping (String) -> Void,
        onSelectFrame: @escaping (Int) -> Void,
        getGlobalIndex: @escaping (FrameAsset) -> Int,
        draggedTimelineItemId: Binding<String?>,
        draggedFrameId: Binding<UUID?>,
        dropIndicatorIndex: Binding<Int?>,
        timelineItems: [TimelineItem],
        indexInTimeline: Int,
        geometry: GeometryProxy
    ) {
        self.item = item
        self.projectId = projectId
        self._currentFrameIndex = currentFrameIndex
        self.metrics = metrics
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMoveFrame = onMoveFrame
        self.onMoveTimelineItem = onMoveTimelineItem
        self.onSetStackId = onSetStackId
        self.onMoveFrameById = onMoveFrameById
        self.onTapAddToStack = onTapAddToStack
        self.onSelectFrame = onSelectFrame
        self.getGlobalIndex = getGlobalIndex
        self._draggedTimelineItemId = draggedTimelineItemId
        self._draggedFrameId = draggedFrameId
        self._dropIndicatorIndex = dropIndicatorIndex
        self.timelineItems = timelineItems
        self.indexInTimeline = indexInTimeline
        self.geometry = geometry
    }

    private func isFrameSelected(_ frame: FrameAsset) -> Bool {
        let globalIndex = getGlobalIndex(frame)
        return globalIndex == currentFrameIndex
    }

    private var isBeingDragged: Bool {
        draggedTimelineItemId == item.id
    }

    var body: some View {
        switch item {
        case .titleFrame:
            SpecialTimelineFrameView(
                systemImage: "textformat",
                metrics: metrics,
                isSelected: indexInTimeline == currentFrameIndex
            )
            .id(item.id)
            .onTapGesture {
                onSelectFrame(indexInTimeline)
            }
            .opacity(isBeingDragged ? 0.3 : 1.0)

        case .singleFrame(let frame):
            SingleFrameView(
                frame: frame,
                projectId: projectId,
                isSelected: isFrameSelected(frame),
                metrics: metrics,
                onDelete: onDelete,
                onDuplicate: onDuplicate,
                onSelect: { onSelectFrame(indexInTimeline) }
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

        case .creditsFrame:
            SpecialTimelineFrameView(
                systemImage: "list.bullet",
                metrics: metrics,
                isSelected: indexInTimeline == currentFrameIndex
            )
            .id(item.id)
            .onTapGesture {
                onSelectFrame(indexInTimeline)
            }
            .opacity(isBeingDragged ? 0.3 : 1.0)
        }
    }
}

private struct SpecialTimelineFrameView: View {
    let systemImage: String
    let metrics: TimelineMetrics
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.65))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }

            Image(systemName: systemImage)
                .font(.system(size: max(14, metrics.frameSize * 0.28), weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: metrics.frameSize, height: metrics.frameSize)
        .contentShape(Rectangle())
    }
}

struct SingleFrameView: View {
    let frame: FrameAsset
    let projectId: UUID
    let isSelected: Bool
    let metrics: TimelineMetrics
    let onDelete: (Int) -> Void
    let onDuplicate: (Int) -> Void
    let onSelect: () -> Void

    var body: some View {
        TimelineThumbnailView(frame: frame, projectId: projectId, isSelected: isSelected)
            .frame(width: metrics.frameSize, height: metrics.frameSize)
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
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .inset(by: 1.5)
                    .stroke(Color.clear, lineWidth: 3)
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
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    )
            }
        }
        .task(id: frame.localFileName) {
            thumbnailImage = await MovieStorage.shared.loadFrame(fileName: frame.localFileName, projectId: projectId)
        }
    }
}
