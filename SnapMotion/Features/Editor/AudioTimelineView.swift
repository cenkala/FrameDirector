//
//  AudioTimelineView.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalılar on 29.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import SwiftUI
import UIKit

struct AudioTimelineView: View {
    @Bindable var viewModel: EditorViewModel
    let height: CGFloat
    @Binding var scrollPosition: Int?
    let scrollAnchorX: CGFloat
    let metrics: TimelineMetrics

    @State private var dragAnchor: (start: Double, end: Double)?
    @State private var leftHandleAnchor: (start: Double, end: Double)?
    @State private var rightHandleAnchor: (start: Double, end: Double)?
    @State private var isSelectionInteracting = false
    @State private var didTriggerSelectionHaptic = false

    private let handleWidth: CGFloat = 14
    private let minSelectionSeconds: Double = 0.1
    private let waveformLineWidth: CGFloat = 1
    private let waveformStep: CGFloat = 3

    init(
        viewModel: EditorViewModel,
        height: CGFloat = 70,
        scrollPosition: Binding<Int?> = .constant(nil),
        scrollAnchorX: CGFloat = 0.5,
        metrics: TimelineMetrics = .regular
    ) {
        self.viewModel = viewModel
        self.height = height
        self._scrollPosition = scrollPosition
        self.scrollAnchorX = scrollAnchorX
        self.metrics = metrics
    }

    var body: some View {
        guard viewModel.hasAudio else { return AnyView(EmptyView()) }

        let duration = viewModel.audioDurationSeconds
        guard duration > 0 else { return AnyView(EmptyView()) }

        let waveform = viewModel.audioWaveform
        let selectionStart = viewModel.audioSelectionStartSeconds
        let selectionEnd = viewModel.audioSelectionEndSeconds

        let totalFrameCount = viewModel.totalFrameCount
        let barWidth = metrics.frameSize
        let barSpacing = metrics.spacing
        let contentWidth = CGFloat(totalFrameCount) * (barWidth + barSpacing)
        let pixelsPerSecond = contentWidth / CGFloat(duration)

        let anchor = UnitPoint(x: min(max(0, scrollAnchorX), 1), y: 0.5)
        let fps = max(viewModel.project.fps, 1)
        let currentTimelineSeconds = Double(viewModel.currentFrameIndex) / Double(fps)
        let playedSeconds = viewModel.isPlaying
            ? min(selectionEnd, max(selectionStart, selectionStart + currentTimelineSeconds))
            : selectionStart

        return AnyView(
            Group {
                if #available(iOS 17.0, *) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .leading) {
                            LazyHStack(spacing: barSpacing) {
                                ForEach(0..<totalFrameCount, id: \.self) { i in
                                    Color.clear
                                        .frame(width: barWidth, height: height)
                                        .id(i)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, 2)
                            .background {
                                waveformBackground(contentWidth: contentWidth)
                            }
                            .overlay {
                                waveformLines(
                                    contentWidth: contentWidth,
                                    waveform: waveform,
                                    duration: duration,
                                    pixelsPerSecond: pixelsPerSecond,
                                    selectionStart: selectionStart,
                                    selectionEnd: selectionEnd,
                                    playedSeconds: playedSeconds
                                )
                            }

                            selectionOverlay(
                                totalFrameCount: totalFrameCount,
                                barWidth: barWidth,
                                barSpacing: barSpacing,
                                pixelsPerSecond: pixelsPerSecond,
                                duration: duration,
                                startSeconds: selectionStart,
                                endSeconds: selectionEnd
                            )
                        }
                    }
                    .scrollDisabled(isSelectionInteracting)
                    .scrollPosition(id: $scrollPosition, anchor: anchor)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: height)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .leading) {
                            HStack(spacing: barSpacing) {
                                ForEach(0..<totalFrameCount, id: \.self) { _ in
                                    Color.clear
                                        .frame(width: barWidth, height: height)
                                }
                            }
                            .padding(.horizontal, 2)
                            .background {
                                waveformBackground(contentWidth: contentWidth)
                            }
                            .overlay {
                                waveformLines(
                                    contentWidth: contentWidth,
                                    waveform: waveform,
                                    duration: duration,
                                    pixelsPerSecond: pixelsPerSecond,
                                    selectionStart: selectionStart,
                                    selectionEnd: selectionEnd,
                                    playedSeconds: playedSeconds
                                )
                            }

                            selectionOverlay(
                                totalFrameCount: totalFrameCount,
                                barWidth: barWidth,
                                barSpacing: barSpacing,
                                pixelsPerSecond: pixelsPerSecond,
                                duration: duration,
                                startSeconds: selectionStart,
                                endSeconds: selectionEnd
                            )
                        }
                    }
                    .scrollDisabled(isSelectionInteracting)
                    .frame(height: height)
                }
            }
        )
    }

    private func waveformBackground(contentWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.Colors.elevatedSurface)
            .frame(width: contentWidth, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.Colors.separator.opacity(0.18), lineWidth: 1)
            }
    }

    private func waveformLines(
        contentWidth: CGFloat,
        waveform: [CGFloat],
        duration: Double,
        pixelsPerSecond: CGFloat,
        selectionStart: Double,
        selectionEnd: Double,
        playedSeconds: Double
    ) -> some View {
        Canvas { context, size in
            guard duration > 0, contentWidth > 0 else { return }

            let insetY: CGFloat = 8
            let centerY = size.height * 0.5
            let maxHalfHeight = max(6, (size.height * 0.5) - insetY)

            let playedColor = Color.secondary.opacity(0.78)
            let unplayedColor = Color.secondary.opacity(0.28)
            let outsideSelectionColor = Color.secondary.opacity(0.14)

            let maxX = min(size.width, contentWidth)
            var x: CGFloat = 0
            while x <= maxX {
                let seconds = Double(x / pixelsPerSecond)
                let normalized = min(1, max(0, seconds / duration))
                let waveformIndex = max(0, min(Int(normalized * Double(max(waveform.count - 1, 0))), max(waveform.count - 1, 0)))
                let amp = (waveformIndex < waveform.count) ? waveform[waveformIndex] : 0

                let halfHeight = max(2, maxHalfHeight * min(1, max(0, amp)))
                let top = CGPoint(x: x, y: centerY - halfHeight)
                let bottom = CGPoint(x: x, y: centerY + halfHeight)

                let isInSelection = seconds >= selectionStart && seconds <= selectionEnd
                let isPlayed = isInSelection && seconds <= playedSeconds

                var path = Path()
                path.move(to: top)
                path.addLine(to: bottom)

                let color = isInSelection ? (isPlayed ? playedColor : unplayedColor) : outsideSelectionColor
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: waveformLineWidth, lineCap: .round))

                x += waveformStep
            }
        }
        .frame(width: contentWidth, height: height)
        .allowsHitTesting(false)
    }

    private func selectionOverlay(
        totalFrameCount: Int,
        barWidth: CGFloat,
        barSpacing: CGFloat,
        pixelsPerSecond: CGFloat,
        duration: Double,
        startSeconds: Double,
        endSeconds: Double
    ) -> some View {
        let contentWidth = CGFloat(totalFrameCount) * (barWidth + barSpacing)
        let startX = CGFloat(startSeconds) * pixelsPerSecond
        let endX = CGFloat(endSeconds) * pixelsPerSecond
        let selectionWidth = max(handleWidth * 2, endX - startX)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.20))
                .frame(width: selectionWidth, height: height)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 1.5)
                }
                .offset(x: startX)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 3.0)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                if !isSelectionInteracting {
                                    isSelectionInteracting = true
                                }
                                if !didTriggerSelectionHaptic {
                                    didTriggerSelectionHaptic = true
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.prepare()
                                    generator.impactOccurred()
                                }

                                let anchor = dragAnchor ?? (start: startSeconds, end: endSeconds)
                                dragAnchor = anchor
                                let deltaSeconds = Double((drag?.translation.width ?? 0) / pixelsPerSecond)
                                let selectionDuration = max(minSelectionSeconds, anchor.end - anchor.start)
                                var newStart = anchor.start + deltaSeconds
                                newStart = max(0, min(newStart, duration - selectionDuration))
                                viewModel.updateAudioSelection(
                                    startSeconds: newStart,
                                    endSeconds: newStart + selectionDuration
                                )
                            default:
                                break
                            }
                        }
                        .onEnded { _ in
                            isSelectionInteracting = false
                            didTriggerSelectionHaptic = false
                            dragAnchor = nil
                        }
                )

            leftHandle(height: height)
                .offset(x: startX)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSelectionInteracting = true
                            let anchor = leftHandleAnchor ?? (start: startSeconds, end: endSeconds)
                            leftHandleAnchor = anchor
                            let deltaSeconds = Double(value.translation.width / pixelsPerSecond)
                            var newStart = anchor.start + deltaSeconds
                            newStart = max(0, min(newStart, anchor.end - minSelectionSeconds))
                            viewModel.updateAudioSelection(startSeconds: newStart, endSeconds: anchor.end)
                        }
                        .onEnded { _ in
                            isSelectionInteracting = false
                            leftHandleAnchor = nil
                        }
                )

            rightHandle(height: height)
                .offset(x: max(0, endX - handleWidth))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSelectionInteracting = true
                            let anchor = rightHandleAnchor ?? (start: startSeconds, end: endSeconds)
                            rightHandleAnchor = anchor
                            let deltaSeconds = Double(value.translation.width / pixelsPerSecond)
                            var newEnd = anchor.end + deltaSeconds
                            newEnd = max(anchor.start + minSelectionSeconds, min(newEnd, duration))
                            viewModel.updateAudioSelection(startSeconds: anchor.start, endSeconds: newEnd)
                        }
                        .onEnded { _ in
                            isSelectionInteracting = false
                            rightHandleAnchor = nil
                        }
                )
        }
        .frame(width: contentWidth, height: height, alignment: .leading)
        .allowsHitTesting(true)
    }

    private func leftHandle(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.90))
            .frame(width: handleWidth, height: height)
            .overlay {
                VStack(spacing: 4) {
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 3, height: 14)
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 3, height: 14)
                }
            }
            .contentShape(Rectangle())
    }

    private func rightHandle(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.90))
            .frame(width: handleWidth, height: height)
            .overlay {
                VStack(spacing: 4) {
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 3, height: 14)
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 3, height: 14)
                }
            }
            .contentShape(Rectangle())
    }
}


