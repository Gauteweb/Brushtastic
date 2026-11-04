import AppKit

/// Tegneverktøy, valgt med tallknappene mens tegnemodus er på.
enum Tool: Int, CaseIterable {
    case freehand = 1
    case ellipse = 2
    case rectangle = 3
    case line = 5

    /// Tasten som velger verktøyet.
    var key: String { String(rawValue) }

    var name: String {
        switch self {
        case .freehand: return L.toolFreehand
        case .ellipse: return L.toolEllipse
        case .rectangle: return L.toolRectangle
        case .line: return L.toolLine
        }
    }

    init?(key: String) {
        guard let n = Int(key), let tool = Tool(rawValue: n) else { return nil }
        self = tool
    }
}

extension Notification.Name {
    /// Sendes når valgt verktøy endres, så overlay og meny kan oppdatere seg.
    static let brushtasticToolChanged = Notification.Name("BrushtasticToolChanged")
}
