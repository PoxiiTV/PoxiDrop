import AppKit
import Carbon.HIToolbox

struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
    let action: () -> Void
}

/// Atajos de teclado globales con Carbon (no necesita el permiso de Accesibilidad).
@MainActor
final class HotKeys {
    private var references: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?

    func register(_ hotKeys: [HotKey]) {
        unregisterAll()
        installHandlerIfNeeded()
        for (index, hotKey) in hotKeys.enumerated() {
            let number = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: OSType(0x5044_5250), id: number) // 'PDRP'
            let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
            guard status == noErr, let reference else { continue }
            references.append(reference)
            actions[number] = hotKey.action
        }
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references = []
        actions = [:]
    }

    fileprivate func fire(_ number: UInt32) {
        actions[number]?()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard let userData else { return noErr }
            let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotKeys.fire(identifier.id) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
