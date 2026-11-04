import AppKit

/// Brukerinnstillinger lagret i UserDefaults.
final class Settings {
    static let shared = Settings()

    static let fadeDelayRange: ClosedRange<Double> = 0.5...10.0
    /// Hvor lenge selve uttoningen varer etter at forsinkelsen har gått.
    static let fadeDuration: Double = 0.4

    private let defaults = UserDefaults.standard
    private enum Key {
        static let fadeDelay = "fadeDelay"
        static let colorIndex = "colorIndex"
        static let lineWidth = "lineWidth"
        static let tool = "tool"
        static let transparency = "transparency"
    }

    static let colors: [(name: String, color: NSColor)] = [
        (L.colorRed, .systemRed),
        (L.colorYellow, .systemYellow),
        (L.colorGreen, .systemGreen),
        (L.colorBlue, .systemBlue),
        (L.colorPink, .systemPink),
        (L.colorWhite, .white),
        (L.colorBlack, .black),
    ]

    static let lineWidths: [(name: String, width: CGFloat)] = [
        (L.widthThin, 3),
        (L.widthMedium, 6),
        (L.widthThick, 12),
    ]

    /// Valgbare gjennomsiktigheter i prosent (0 = helt dekkende).
    static let transparencies: [Int] = [0, 25, 50, 75]

    private init() {
        defaults.register(defaults: [
            Key.fadeDelay: 3.0,
            Key.colorIndex: 0,
            Key.lineWidth: 6.0,
            Key.transparency: 0,
        ])
    }

    /// Gjennomsiktighet for nye streker, i prosent.
    var transparency: Int {
        get {
            let v = defaults.integer(forKey: Key.transparency)
            return Self.transparencies.contains(v) ? v : 0
        }
        set { defaults.set(newValue, forKey: Key.transparency) }
    }

    /// Dekkevne for nye streker (1 = helt dekkende).
    var opacity: CGFloat { 1 - CGFloat(transparency) / 100 }

    /// Glidebryterens ytterste posisjon til høyre: strekene fader aldri.
    static let neverFadeSliderValue: Double = fadeDelayRange.upperBound + 0.5
    static let sliderRange: ClosedRange<Double> = fadeDelayRange.lowerBound...neverFadeSliderValue

    /// Rå verdi fra glidebryteren (0,5–10 s, eller `neverFadeSliderValue` for «aldri»).
    var fadeDelaySliderValue: Double {
        get {
            let v = defaults.double(forKey: Key.fadeDelay)
            return min(max(v, Self.sliderRange.lowerBound), Self.sliderRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, Self.sliderRange.lowerBound), Self.sliderRange.upperBound)
            defaults.set(clamped, forKey: Key.fadeDelay)
        }
    }

    var neverFades: Bool { fadeDelaySliderValue >= Self.neverFadeSliderValue }

    /// Forsinkelse før uttoning, i sekunder. `.infinity` når strekene aldri skal fade.
    var fadeDelay: Double {
        neverFades ? .infinity : fadeDelaySliderValue
    }

    var colorIndex: Int {
        get {
            let i = defaults.integer(forKey: Key.colorIndex)
            return Self.colors.indices.contains(i) ? i : 0
        }
        set { defaults.set(newValue, forKey: Key.colorIndex) }
    }

    var color: NSColor { Self.colors[colorIndex].color }

    var lineWidth: CGFloat {
        get { CGFloat(defaults.double(forKey: Key.lineWidth)) }
        set { defaults.set(Double(newValue), forKey: Key.lineWidth) }
    }

    var tool: Tool {
        get { Tool(rawValue: defaults.integer(forKey: Key.tool)) ?? .freehand }
        set {
            defaults.set(newValue.rawValue, forKey: Key.tool)
            NotificationCenter.default.post(name: .brushtasticToolChanged, object: nil)
        }
    }
}
