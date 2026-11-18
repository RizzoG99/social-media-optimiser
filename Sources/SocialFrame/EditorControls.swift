import SwiftUI

/// Native tracking keeps dragging responsive; a delayed single click lets a
/// double click reset without committing the first click to document history.
struct ResettableSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let initial: Double
    var begin: () -> Void = {}
    var checkpoint: ((Double) -> Void)? = nil
    func makeNSView(context: Context) -> ResetSlider {
        let slider = ResetSlider()
        slider.target = slider; slider.action = #selector(ResetSlider.changed)
        slider.isContinuous = true
        return slider
    }
    func updateNSView(_ slider: ResetSlider, context: Context) {
        slider.minValue = range.lowerBound; slider.maxValue = range.upperBound
        if !slider.tracking { slider.doubleValue = value }
        slider.commit = { newValue, first in
            if first, let checkpoint { checkpoint(newValue) } else { value = newValue }
        }
        slider.resetValue = initial
    }
}
final class ResetSlider: NSSlider {
    var commit: ((Double, Bool) -> Void)?
    var resetValue = 0.0
    var tracking = false
    private var dragged = false
    private var pending: DispatchWorkItem?
    @objc func changed() {
        if NSApp.currentEvent?.type == .leftMouseDragged {
            commit?(doubleValue, !dragged); dragged = true
        } else if !tracking { commit?(doubleValue, true) }
    }
    override func mouseDown(with event: NSEvent) {
        pending?.cancel()
        if event.clickCount == 2 {
            doubleValue = resetValue; commit?(resetValue, true)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.doubleValue = self.resetValue
            }
            return
        }
        tracking = true; dragged = false
        var pointerEvent = event
        while true {
            let point = convert(pointerEvent.locationInWindow, from: nil)
            // Reserve half a knob at either end, matching the native track.
            let fraction = min(1, max(0, (point.x - 8) / max(1, bounds.width - 16)))
            doubleValue = minValue + fraction * (maxValue - minValue)
            if pointerEvent.type == .leftMouseDragged {
                commit?(doubleValue, !dragged); dragged = true
            }
            guard let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if next.type == .leftMouseUp { break }
            pointerEvent = next
        }
        tracking = false
        let result = doubleValue
        if dragged { commit?(result, false) }
        else {
            let work = DispatchWorkItem { [weak self] in self?.commit?(result, true) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: work)
        }
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { pending?.cancel() }
        super.viewWillMove(toWindow: newWindow)
    }
}

struct CanvasPointer: NSViewRepresentable {
    let clone: Bool
    func makeNSView(context: Context) -> PointerView { PointerView() }
    func updateNSView(_ view: PointerView, context: Context) {
        view.cursor = clone ? .crosshair : .openHand
        view.window?.invalidateCursorRects(for: view)
    }
}
final class PointerView: NSView {
    var cursor: NSCursor = .openHand
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func resetCursorRects() { addCursorRect(visibleRect, cursor: cursor) }
}

struct CloneToolIcon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: r.width * 0.32, y: 0, width: r.width * 0.36, height: r.height * 0.55), cornerSize: CGSize(width: 3, height: 3))
        p.addRoundedRect(in: CGRect(x: r.width * 0.08, y: r.height * 0.55, width: r.width * 0.84, height: r.height * 0.22), cornerSize: CGSize(width: 2, height: 2))
        p.addRect(CGRect(x: 0, y: r.height * 0.88, width: r.width, height: r.height * 0.1))
        return p
    }
}

struct CropOverlay: View {
    @Binding var rect: CGRect
    let minimum: CGFloat
    @State private var origin: CGRect?
    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            Path { p in
                p.addRect(CGRect(origin: .zero, size: s))
                p.addRect(CGRect(x: rect.minX * s.width, y: rect.minY * s.height, width: rect.width * s.width, height: rect.height * s.height))
            }.fill(.black.opacity(0.55), style: FillStyle(eoFill: true)).allowsHitTesting(false)
            Rectangle().stroke(.white, lineWidth: 1)
                .frame(width: rect.width * s.width, height: rect.height * s.height)
                .position(x: rect.midX * s.width, y: rect.midY * s.height).allowsHitTesting(false)
            ForEach(0..<8) { index in
                let x: CGFloat = [0, 0.5, 1, 1, 1, 0.5, 0, 0][index]
                let y: CGFloat = [0, 0, 0, 0.5, 1, 1, 1, 0.5][index]
                Rectangle().fill(.white).frame(width: 12, height: 12)
                    .padding(6).contentShape(Rectangle())
                    .position(x: (rect.minX + x * rect.width) * s.width, y: (rect.minY + y * rect.height) * s.height)
                    .gesture(DragGesture().onChanged { v in
                        if origin == nil { origin = rect }
                        guard let o = origin else { return }
                        let dx = v.translation.width / s.width, dy = v.translation.height / s.height
                        let delta = x == 0.5 ? (y == 0 ? -dy : dy) : y == 0.5 ? (x == 0 ? -dx : dx) : abs(dx) > abs(dy) ? (x == 0 ? -dx : dx) : (y == 0 ? -dy : dy)
                        let anchorX = x == 0.5 ? o.midX : x == 0 ? o.maxX : o.minX
                        let anchorY = y == 0.5 ? o.midY : y == 0 ? o.maxY : o.minY
                        let maxX = x == 0.5 ? 2 * min(anchorX, 1-anchorX) : x == 0 ? anchorX : 1-anchorX
                        let maxY = y == 0.5 ? 2 * min(anchorY, 1-anchorY) : y == 0 ? anchorY : 1-anchorY
                        let side = min(maxX, maxY, max(minimum, o.width + delta))
                        rect = CGRect(x: x == 0.5 ? anchorX-side/2 : x == 0 ? anchorX-side : anchorX,
                                      y: y == 0.5 ? anchorY-side/2 : y == 0 ? anchorY-side : anchorY, width: side, height: side)
                    }.onEnded { _ in origin = nil })
                    .onHover { inside in
                        if inside { (x == 0.5 ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).set() }
                        else { NSCursor.arrow.set() }
                    }
                    .accessibilityLabel(Text("Maniglia ritaglio"))
            }
        }
    }
}
