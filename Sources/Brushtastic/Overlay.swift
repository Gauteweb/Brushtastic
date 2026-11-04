import AppKit

/// Gjennomsiktig, kantløst panel som dekker én skjerm.
final class OverlayPanel: NSPanel {
    init(screen: NSScreen, store: StrokeStore) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        // Synlig på alle Spaces, også over fullskjermsapper, og ikke med i Exposé/Mission Control.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovable = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true

        let view = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size), store: store)
        view.autoresizingMask = [.width, .height]
        contentView = view
        initialFirstResponder = view
        makeFirstResponder(view)
        setFrame(screen.frame, display: false)
    }

    var overlayView: OverlayView { contentView as! OverlayView }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func becomeKey() {
        super.becomeKey()
        // Tastetrykk (1/2/3/5, Esc) skal alltid havne i visningen.
        if firstResponder !== overlayView { makeFirstResponder(overlayView) }
    }

    func setDrawingMode(_ on: Bool) {
        ignoresMouseEvents = !on
        overlayView.drawingMode = on
    }
}

final class OverlayView: NSView {
    private let store: StrokeStore
    var drawingMode = false {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            if drawingMode { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
        }
    }

    init(frame: CGRect, store: StrokeStore) {
        self.store = store
        super.init(frame: frame)
        wantsLayer = true
        NotificationCenter.default.addObserver(forName: .brushtasticToolChanged, object: nil,
                                               queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseMoved, .mouseEnteredAndExited],
                                       owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        if drawingMode { NSCursor.crosshair.set() } else { super.cursorUpdate(with: event) }
    }

    override func mouseMoved(with event: NSEvent) {
        if drawingMode { NSCursor.crosshair.set() }
    }

    override func mouseEntered(with event: NSEvent) {
        if drawingMode {
            NSCursor.crosshair.set()
            // Gjør panelet under musa til key-vindu, så tastene treffer.
            window?.makeKey()
        }
    }

    // MARK: Tegning med mus

    /// Global musposisjon, så streken fortsetter riktig over andre skjermer.
    private var mousePoint: CGPoint { NSEvent.mouseLocation }

    private func isShift(_ event: NSEvent) -> Bool { event.modifierFlags.contains(.shift) }

    override func mouseDown(with event: NSEvent) {
        guard drawingMode else { return }
        window?.makeKey()
        store.begin(at: mousePoint, constrained: isShift(event))
    }

    override func mouseDragged(with event: NSEvent) {
        guard drawingMode else { return }
        store.append(mousePoint, constrained: isShift(event))
    }

    override func mouseUp(with event: NSEvent) {
        guard drawingMode else { return }
        store.append(mousePoint, constrained: isShift(event))
        store.end()
    }

    override func flagsChanged(with event: NSEvent) {
        // Shift trykket/sluppet midt i en figur: oppdater uten at musa må flyttes.
        if drawingMode, store.current != nil {
            store.append(mousePoint, constrained: isShift(event))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // Høyreklikk visker alt.
        if drawingMode { store.clear() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            NotificationCenter.default.post(name: .brushtasticExitDrawing, object: nil)
            return
        }
        if drawingMode,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let chars = event.charactersIgnoringModifiers,
           let tool = Tool(key: chars) {
            if store.current != nil { store.end() }
            Settings.shared.tool = tool
            return
        }
        super.keyDown(with: event)
    }

    // MARK: Rendering

    override func draw(_ dirtyRect: NSRect) {
        guard let window else { return }
        NSColor.clear.set()
        dirtyRect.fill()

        if drawingMode {
            // Svak indikasjon på at tegnemodus er på.
            NSColor.black.withAlphaComponent(0.04).setFill()
            bounds.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
            let border = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
            border.lineWidth = 3
            border.stroke()
        }

        let origin = window.frame.origin
        let now = CACurrentMediaTime()
        let delay = Settings.shared.fadeDelay
        let duration = Settings.fadeDuration
        let visibleScreenRect = window.frame

        for stroke in store.strokes {
            guard stroke.bounds.intersects(visibleScreenRect) else { continue }
            let alpha = stroke.alpha(at: now, delay: delay, duration: duration)
            guard alpha > 0 else { continue }

            let local = stroke.points.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
            let path = Self.path(for: stroke.tool, points: local, constrained: stroke.constrained)
            path.lineWidth = stroke.width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            // Uttoning ganget med valgt gjennomsiktighet. Hele streken tegnes i én operasjon,
            // så der den krysser seg selv blir den ikke mørkere.
            stroke.color.withAlphaComponent(alpha * stroke.opacity).setStroke()
            path.stroke()
        }

        if drawingMode { drawToolBar() }
    }

    // MARK: Verktøylinje

    /// Liten pille øverst på skjermen som viser verktøyene og hvilket som er valgt.
    private func drawToolBar() {
        let current = Settings.shared.tool
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let keyFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

        struct Segment { let key: NSAttributedString; let label: NSAttributedString; let selected: Bool; let width: CGFloat }
        let segments: [Segment] = Tool.allCases.map { tool in
            let selected = tool == current
            let color: NSColor = selected ? .white : NSColor.white.withAlphaComponent(0.75)
            let key = NSAttributedString(string: tool.key, attributes: [.font: keyFont, .foregroundColor: color])
            let label = NSAttributedString(string: tool.name, attributes: [.font: font, .foregroundColor: color])
            return Segment(key: key, label: label, selected: selected,
                           width: 10 + 18 + 6 + ceil(label.size().width) + 12)
        }

        let height: CGFloat = 32
        let padding: CGFloat = 4
        let totalWidth = segments.reduce(0) { $0 + $1.width } + padding * 2

        // Plasser under menylinjen (og en eventuell notch).
        var topInset: CGFloat = 24
        if let screen = window?.screen {
            topInset = max(topInset, screen.frame.maxY - screen.visibleFrame.maxY)
            if #available(macOS 12.0, *) { topInset = max(topInset, screen.safeAreaInsets.top) }
        }
        let bar = CGRect(x: (bounds.width - totalWidth) / 2,
                         y: bounds.maxY - topInset - 12 - height,
                         width: totalWidth, height: height)

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: bar, xRadius: height / 2, yRadius: height / 2).fill()

        var x = bar.minX + padding
        for seg in segments {
            let segRect = CGRect(x: x, y: bar.minY + padding, width: seg.width, height: height - padding * 2)
            if seg.selected {
                NSColor.controlAccentColor.setFill()
                let r = (height - padding * 2) / 2
                NSBezierPath(roundedRect: segRect, xRadius: r, yRadius: r).fill()
            }
            // Tasten i en liten boks
            let keyBox = CGRect(x: segRect.minX + 10, y: segRect.midY - 9, width: 18, height: 18)
            NSColor.white.withAlphaComponent(seg.selected ? 0.3 : 0.18).setFill()
            NSBezierPath(roundedRect: keyBox, xRadius: 4, yRadius: 4).fill()
            let ks = seg.key.size()
            seg.key.draw(at: CGPoint(x: keyBox.midX - ks.width / 2, y: keyBox.midY - ks.height / 2))

            let ls = seg.label.size()
            seg.label.draw(at: CGPoint(x: keyBox.maxX + 6, y: segRect.midY - ls.height / 2))
            x += seg.width
        }
    }

    // MARK: Geometri

    static func path(for tool: Tool, points: [CGPoint], constrained: Bool) -> NSBezierPath {
        switch tool {
        case .freehand:
            return smoothPath(points)
        case .ellipse, .rectangle:
            guard points.count == 2 else { return NSBezierPath() }
            let rect = shapeRect(from: points[0], to: points[1], square: constrained)
            return tool == .ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
        case .line:
            guard points.count == 2 else { return NSBezierPath() }
            let end = constrained ? snapped45(from: points[0], to: points[1]) : points[1]
            let path = NSBezierPath()
            path.move(to: points[0])
            path.line(to: end)
            return path
        }
    }

    /// Rektangel mellom to hjørner; med `square` blir sidene like lange (sirkel/kvadrat).
    private static func shapeRect(from a: CGPoint, to b: CGPoint, square: Bool) -> CGRect {
        var dx = b.x - a.x, dy = b.y - a.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        return CGRect(x: min(a.x, a.x + dx), y: min(a.y, a.y + dy), width: abs(dx), height: abs(dy))
    }

    /// Lås vinkelen til nærmeste 45°.
    private static func snapped45(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = hypot(dx, dy)
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        return CGPoint(x: a.x + cos(angle) * length, y: a.y + sin(angle) * length)
    }

    /// Glatter streken med kvadratiske kurver gjennom midtpunktene.
    private static func smoothPath(_ pts: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count == 1 {
            path.line(to: first) // prikk (round cap gir en sirkel)
            return path
        }
        if pts.count == 2 {
            path.line(to: pts[1])
            return path
        }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            // NSBezierPath har ikke quadCurve før macOS 14; konverter til kubisk.
            let p0 = path.currentPoint
            let c = pts[i]
            let c1 = CGPoint(x: p0.x + 2.0 / 3.0 * (c.x - p0.x), y: p0.y + 2.0 / 3.0 * (c.y - p0.y))
            let c2 = CGPoint(x: mid.x + 2.0 / 3.0 * (c.x - mid.x), y: mid.y + 2.0 / 3.0 * (c.y - mid.y))
            path.curve(to: mid, controlPoint1: c1, controlPoint2: c2)
        }
        path.line(to: pts[pts.count - 1])
        return path
    }
}

extension Notification.Name {
    static let brushtasticExitDrawing = Notification.Name("BrushtasticExitDrawing")
}
