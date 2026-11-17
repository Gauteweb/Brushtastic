import AppKit
import ScreenCaptureKit

/// Utsnittet brukeren drar ut når et skjermbilde tas, i globale skjermkoordinater
/// (samme som strekene). Holdes på én skjerm: den der dragningen startet.
final class ScreenshotSelection {
    private(set) var screen: NSScreen?
    private var start: CGPoint?
    private var end: CGPoint?

    /// Kalles når utsnittet endres og må tegnes på nytt.
    var onChange: (() -> Void)?
    /// Kalles med ferdig utsnitt og skjermen det ligger på.
    var onFinish: ((CGRect, NSScreen) -> Void)?
    /// Kalles når brukeren avbryter (Esc, høyreklikk eller bare et klikk).
    var onCancel: (() -> Void)?

    /// Utsnittet slik det er nå, avgrenset til skjermen.
    var rect: CGRect? {
        guard let start, let end, let screen else { return nil }
        let r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                       width: abs(end.x - start.x), height: abs(end.y - start.y))
        return r.intersection(screen.frame).integral
    }

    func reset() {
        start = nil
        end = nil
        screen = nil
        onChange?()
    }

    func begin(at point: CGPoint) {
        screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        start = point
        end = point
        onChange?()
    }

    func update(to point: CGPoint) {
        guard start != nil else { return }
        end = point
        onChange?()
    }

    func finish(at point: CGPoint) {
        update(to: point)
        // Et klikk uten å dra avbryter, som i macOS' eget skjermbildeverktøy.
        guard let rect, let screen, rect.width >= 3, rect.height >= 3 else {
            cancel()
            return
        }
        onFinish?(rect, screen)
    }

    func cancel() {
        onCancel?()
    }
}

/// Tar bildet med ScreenCaptureKit, i appen selv. Da er det Brushtastic som har
/// tillatelsen til skjermopptak, og macOS husker den (i motsetning til når
/// hjelpeprogrammet `screencapture` startes fra appen).
enum Screenshotter {
    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    /// Tar bilde av `rect` (globale koordinater) på `screen`, med alle vinduer,
    /// også Brushtastics egne overlay-vinduer med strekene.
    static func capture(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = screen.deviceDescription[key] as? CGDirectDisplayID else {
            throw Failure(errorDescription: "Unknown display")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw Failure(errorDescription: "Display not available for capture")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // sourceRect er i punkter med origo øverst til venstre på skjermen.
        let frame = screen.frame
        config.sourceRect = CGRect(x: rect.minX - frame.minX, y: frame.maxY - rect.maxY,
                                   width: rect.width, height: rect.height)
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int((rect.width * scale).rounded())
        config.height = Int((rect.height * scale).rounded())
        config.captureResolution = .best
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Legger bildet på utklippstavla som PNG (og TIFF for eldre apper).
    static func copyToClipboard(_ image: CGImage) {
        let rep = NSBitmapImageRep(cgImage: image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }
}
