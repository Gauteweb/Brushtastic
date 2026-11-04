import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menylinje-app: ingen dock-ikon, ingen hovedmeny.
app.setActivationPolicy(.accessory)
app.run()
