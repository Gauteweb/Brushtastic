import Carbon.HIToolbox

/// Global hurtigtast via Carbon `RegisterEventHotKey`.
/// Krever ikke tilgjengelighetstillatelse (Accessibility).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    private static let signature: OSType = {
        // 'BRSH'
        let chars: [UInt8] = Array("BRSH".utf8)
        return chars.reduce(0) { ($0 << 8) | OSType($1) }
    }()

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            guard hkID.signature == HotKey.signature else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        guard status == noErr else { return nil }

        let hkID = EventHotKeyID(signature: Self.signature, id: 1)
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hkID,
                                            GetApplicationEventTarget(), 0, &hotKeyRef)
        guard regStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
