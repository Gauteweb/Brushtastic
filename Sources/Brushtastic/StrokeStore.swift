import AppKit

/// Én strek eller figur, lagret i globale skjermkoordinater (Cocoa: origo nede til venstre
/// på hovedskjermen), slik at den kan krysse flere skjermer.
final class Stroke {
    let tool: Tool
    /// Frihånd: alle punktene. Figurer: [startpunkt, sluttpunkt].
    var points: [CGPoint]
    let color: NSColor
    let width: CGFloat
    /// Shift holdt inne: sirkel/kvadrat med like sider, rett strek låst til 45°-vinkler.
    var constrained = false
    /// Settes når musknappen slippes; uttoningen starter først etter dette.
    var finishedAt: CFTimeInterval?

    init(tool: Tool, start: CGPoint, color: NSColor, width: CGFloat) {
        self.tool = tool
        self.points = tool == .freehand ? [start] : [start, start]
        self.color = color
        self.width = width
    }

    var bounds: CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        var r = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        if constrained, tool != .freehand {
            // Låst figur kan gå litt utenfor punktene; ta med hele kvadratet rundt startpunktet.
            let side = max(r.width, r.height)
            r = CGRect(x: first.x - side, y: first.y - side, width: side * 2, height: side * 2)
        }
        return r.insetBy(dx: -width, dy: -width)
    }

    /// Er figuren så liten at den bare var et klikk? (Gjelder ikke frihånd, der et klikk gir en prikk.)
    var isNegligibleShape: Bool {
        guard tool != .freehand, points.count == 2 else { return false }
        return hypot(points[1].x - points[0].x, points[1].y - points[0].y) < 3
    }

    func alpha(at now: CFTimeInterval, delay: Double, duration: Double) -> CGFloat {
        guard let finishedAt else { return 1 }
        let elapsed = now - finishedAt - delay
        if elapsed <= 0 { return 1 }
        return CGFloat(max(0, 1 - elapsed / duration))
    }
}

/// Felles lager for alle streker. Driver animasjonen og varsler overlay-vinduene.
final class StrokeStore {
    private(set) var strokes: [Stroke] = []
    private(set) var current: Stroke?
    private var timer: Timer?

    /// Kalles når noe må tegnes på nytt.
    var onChange: (() -> Void)?

    func begin(at point: CGPoint, constrained: Bool) {
        let s = Stroke(tool: Settings.shared.tool, start: point,
                       color: Settings.shared.color, width: Settings.shared.lineWidth)
        s.constrained = constrained
        strokes.append(s)
        current = s
        onChange?()
    }

    func append(_ point: CGPoint, constrained: Bool) {
        guard let current else { return }
        current.constrained = constrained
        if current.tool == .freehand {
            if let last = current.points.last, hypot(last.x - point.x, last.y - point.y) < 0.75 { return }
            current.points.append(point)
        } else {
            // Figurer: bare sluttpunktet følger musa.
            current.points[1] = point
        }
        onChange?()
    }

    func end() {
        guard let current else { return }
        self.current = nil
        if current.isNegligibleShape {
            strokes.removeAll { $0 === current }
        } else {
            current.finishedAt = CACurrentMediaTime()
            startTimerIfNeeded()
        }
        onChange?()
    }

    func clear() {
        strokes.removeAll()
        current = nil
        stopTimer()
        onChange?()
    }

    /// Kalles når brukeren går mellom «fader aldri» og en vanlig forsinkelse.
    /// Ferdige streker får ny starttid, så de ikke forsvinner med en gang
    /// når «aldri» slås av, men fader etter valgt forsinkelse.
    func fadeModeChanged() {
        if Settings.shared.neverFades {
            stopTimer()
        } else {
            let now = CACurrentMediaTime()
            strokes.forEach { if $0.finishedAt != nil { $0.finishedAt = now } }
            startTimerIfNeeded()
        }
        onChange?()
    }

    private func startTimerIfNeeded() {
        // Ingen animasjon trengs når strekene aldri fader.
        guard timer == nil, !Settings.shared.neverFades else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common slik at animasjonen fortsetter mens menyen er åpen.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if Settings.shared.neverFades { stopTimer(); return }
        let now = CACurrentMediaTime()
        let delay = Settings.shared.fadeDelay
        let duration = Settings.fadeDuration
        let before = strokes.count
        strokes.removeAll { $0.finishedAt != nil && $0.alpha(at: now, delay: delay, duration: duration) <= 0 }

        let anyFading = strokes.contains { s in
            guard let f = s.finishedAt else { return false }
            return now - f >= delay
        }
        if anyFading || strokes.count != before { onChange?() }

        if !strokes.contains(where: { $0.finishedAt != nil }) { stopTimer() }
    }
}
