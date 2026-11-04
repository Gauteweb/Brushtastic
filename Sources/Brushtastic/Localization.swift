import Foundation

/// Alle tekster brukeren ser, på norsk og engelsk.
/// Norsk brukes når systemets foretrukne språk er norsk (bokmål, nynorsk eller «norsk»),
/// ellers engelsk. Språket velges én gang ved oppstart.
struct L10n {
    let startDrawing: String
    let stopDrawing: String
    let clearAll: String
    let fadeNever: String
    let fadeAfter: (String) -> String
    let tool: String
    let color: String
    let lineWidth: String
    let transparency: String
    let launchAtLogin: String
    let launchAtLoginPending: String
    let launchAtLoginError: String
    let hintExit: String
    let hintShift: String
    let quit: String

    let toolFreehand: String
    let toolEllipse: String
    let toolRectangle: String
    let toolLine: String

    let colorRed: String
    let colorYellow: String
    let colorGreen: String
    let colorBlue: String
    let colorPink: String
    let colorWhite: String
    let colorBlack: String

    let widthThin: String
    let widthMedium: String
    let widthThick: String

    /// Locale for tallformat (desimalkomma på norsk, punktum på engelsk).
    let numberLocale: Locale

    static let norwegian = L10n(
        startDrawing: "Start tegning",
        stopDrawing: "Stopp tegning",
        clearAll: "Visk ut alt",
        fadeNever: "Fader aldri ut",
        fadeAfter: { "Fader ut etter \($0) s" },
        tool: "Verktøy",
        color: "Farge",
        lineWidth: "Strektykkelse",
        transparency: "Gjennomsiktighet",
        launchAtLogin: "Start ved innlogging",
        launchAtLoginPending: "Start ved innlogging (venter på godkjenning)",
        launchAtLoginError: "Kunne ikke endre oppstart ved innlogging",
        hintExit: "Esc eller ⌃⌥D avslutter · høyreklikk visker",
        hintShift: "Hold ⇧ for perfekt sirkel/kvadrat og 45° strek",
        quit: "Avslutt Brushtastic",
        toolFreehand: "Frihånd",
        toolEllipse: "Sirkel",
        toolRectangle: "Firkant",
        toolLine: "Rett strek",
        colorRed: "Rød",
        colorYellow: "Gul",
        colorGreen: "Grønn",
        colorBlue: "Blå",
        colorPink: "Rosa",
        colorWhite: "Hvit",
        colorBlack: "Svart",
        widthThin: "Tynn",
        widthMedium: "Middels",
        widthThick: "Tykk",
        numberLocale: Locale(identifier: "nb_NO")
    )

    static let english = L10n(
        startDrawing: "Start Drawing",
        stopDrawing: "Stop Drawing",
        clearAll: "Clear All",
        fadeNever: "Never fade out",
        fadeAfter: { "Fade out after \($0) s" },
        tool: "Tool",
        color: "Color",
        lineWidth: "Line Width",
        transparency: "Transparency",
        launchAtLogin: "Launch at Login",
        launchAtLoginPending: "Launch at Login (awaiting approval)",
        launchAtLoginError: "Could not change Launch at Login",
        hintExit: "Esc or ⌃⌥D exits · right-click clears",
        hintShift: "Hold ⇧ for perfect circle/square and 45° lines",
        quit: "Quit Brushtastic",
        toolFreehand: "Freehand",
        toolEllipse: "Circle",
        toolRectangle: "Rectangle",
        toolLine: "Straight Line",
        colorRed: "Red",
        colorYellow: "Yellow",
        colorGreen: "Green",
        colorBlue: "Blue",
        colorPink: "Pink",
        colorWhite: "White",
        colorBlack: "Black",
        widthThin: "Thin",
        widthMedium: "Medium",
        widthThick: "Thick",
        numberLocale: Locale(identifier: "en_US")
    )

    /// Språkkoder som regnes som norsk: bokmål, nynorsk og den generelle «no».
    private static let norwegianCodes: Set<String> = ["nb", "nn", "no"]

    static let isNorwegian: Bool = {
        // Første foretrukne språk, f.eks. "nb-NO", "nn", "no-NO" eller "en-GB".
        // Respekterer også språk valgt for appen alene i Systeminnstillinger.
        guard let preferred = Locale.preferredLanguages.first else { return false }
        let code = preferred.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? preferred
        return norwegianCodes.contains(code.lowercased())
    }()

    static let current: L10n = isNorwegian ? .norwegian : .english

    /// Prosent i språkets format: «25 %» på norsk, «25%» på engelsk.
    func percent(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.locale = numberLocale
        return f.string(from: NSNumber(value: Double(value) / 100)) ?? "\(value) %"
    }
}

/// Kortform: `L.startDrawing`
let L = L10n.current
