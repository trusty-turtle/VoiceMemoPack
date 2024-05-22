import SwiftUI

import SwiftUI


struct RangeSlider_NEW: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let mainColor: Color
    let thumbSideSize: Double
    let trackHeight: Double
    let performOnEnd: () -> Void
    let onDragBegan: () -> Void

    @State private var isDraggingLeftThumb = false
    @State private var isDraggingRightThumb = false
    @State private var dragStartValue: Double = 0

   // @State private var trackWidth: CGFloat = 0 // Will be dynamically calculated // <----- removed

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - thumbSideSize
            ZStack(alignment: .leading) {
                trackView
                thumbView(side: .left, trackWidth: trackWidth, offset: lowerValue * trackWidth)
                thumbView(side: .right, trackWidth: trackWidth, offset: upperValue * trackWidth)
            }
        }
        .frame(height: thumbSideSize)
    }

    private var trackView: some View {
        Rectangle()
            .foregroundColor(mainColor)
            .frame(height: trackHeight)
            .padding([.leading,.trailing], thumbSideSize/2)
    }

    private func thumbView(side: ThumbSide, trackWidth: Double, offset: Double) -> some View {
        Circle()
            .frame(width: thumbSideSize, height: thumbSideSize)
            .foregroundColor(mainColor)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragChanged(value, side: side, trackWidth: trackWidth)
                    }
                    .onEnded { _ in
                        dragEnded(for: side)
                    }
            )
    }

    private func dragChanged(_ value: DragGesture.Value, side: ThumbSide, trackWidth: Double) {
        let normalizedDelta = value.translation.width / trackWidth
        switch side {
        case .left:
            guard !isDraggingRightThumb else { return }
            if !isDraggingLeftThumb {
                dragStartValue = lowerValue
                isDraggingLeftThumb = true
                onDragBegan()
            }
            var newValue = dragStartValue + normalizedDelta
            let limit = upperValue - thumbSideSize / trackWidth
            newValue = max(min(newValue, limit), 0)
            lowerValue = newValue
        case .right:
            guard !isDraggingLeftThumb else { return }
            if !isDraggingRightThumb {
                dragStartValue = upperValue
                isDraggingRightThumb = true
                onDragBegan()
            }
            var newValue = dragStartValue + normalizedDelta
            let limit = lowerValue + thumbSideSize / trackWidth
            newValue = min(max(newValue, limit), 1)
            upperValue = newValue
        }
    }
    
    private func dragEnded(for side: ThumbSide) {
        switch side {
        case .left:
            isDraggingLeftThumb = false
        case .right:
            isDraggingRightThumb = false
        }
        performOnEnd()
    }

    enum ThumbSide {
        case left, right
    }
}

