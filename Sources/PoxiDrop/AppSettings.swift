import AppKit
import Combine
import PoxiDropCore

enum ModifierChoice: String, CaseIterable, Identifiable {
    case shift, control, option, command

    var id: String { rawValue }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .control: return .control
        case .option: return .option
        case .command: return .command
        }
    }

    var label: String {
        switch self {
        case .shift: return "⇧ Mayúsculas"
        case .control: return "⌃ Control"
        case .option: return "⌥ Opción"
        case .command: return "⌘ Comando"
        }
    }
}

enum DragOutMode: String, CaseIterable, Identifiable {
    case copy, move
    var id: String { rawValue }
    var label: String { self == .copy ? "Copiar" : "Mover" }
}

enum DetailLayout: String {
    case grid, list
}

/// Ajustes de la app, guardados en UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let shakeEnabled = "shakeEnabled"
        static let shakeSensitivity = "shakeSensitivity"
        static let modifierEnabled = "modifierEnabled"
        static let modifierKey = "modifierKey"
        static let notchEnabled = "notchEnabled"
        static let quickActionsEnabled = "quickActionsEnabled"
        static let dragOutMode = "dragOutMode"
        static let closeWhenEmpty = "closeWhenEmpty"
        static let detailLayout = "detailLayout"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hotkeysEnabled = "hotkeysEnabled"
        static let customScripts = "customScripts"
    }

    private let defaults: UserDefaults

    @Published var shakeEnabled: Bool { didSet { defaults.set(shakeEnabled, forKey: Key.shakeEnabled) } }
    @Published var shakeSensitivity: Int { didSet { defaults.set(shakeSensitivity, forKey: Key.shakeSensitivity) } }
    @Published var modifierEnabled: Bool { didSet { defaults.set(modifierEnabled, forKey: Key.modifierEnabled) } }
    @Published var modifierKey: ModifierChoice { didSet { defaults.set(modifierKey.rawValue, forKey: Key.modifierKey) } }
    @Published var notchEnabled: Bool { didSet { defaults.set(notchEnabled, forKey: Key.notchEnabled) } }
    @Published var quickActionsEnabled: Bool { didSet { defaults.set(quickActionsEnabled, forKey: Key.quickActionsEnabled) } }
    @Published var dragOutMode: DragOutMode { didSet { defaults.set(dragOutMode.rawValue, forKey: Key.dragOutMode) } }
    @Published var closeWhenEmpty: Bool { didSet { defaults.set(closeWhenEmpty, forKey: Key.closeWhenEmpty) } }
    @Published var detailLayout: DetailLayout { didSet { defaults.set(detailLayout.rawValue, forKey: Key.detailLayout) } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon) } }
    @Published var hotkeysEnabled: Bool { didSet { defaults.set(hotkeysEnabled, forKey: Key.hotkeysEnabled) } }
    @Published var customScripts: [CustomScript] {
        didSet { defaults.set(try? JSONEncoder().encode(customScripts), forKey: Key.customScripts) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.shakeEnabled: true,
            Key.shakeSensitivity: 1,
            Key.modifierEnabled: false,
            Key.modifierKey: ModifierChoice.shift.rawValue,
            Key.notchEnabled: true,
            Key.quickActionsEnabled: true,
            Key.dragOutMode: DragOutMode.copy.rawValue,
            Key.closeWhenEmpty: true,
            Key.detailLayout: DetailLayout.grid.rawValue,
            Key.showMenuBarIcon: true,
            Key.hotkeysEnabled: true,
        ])
        shakeEnabled = defaults.bool(forKey: Key.shakeEnabled)
        shakeSensitivity = defaults.integer(forKey: Key.shakeSensitivity)
        modifierEnabled = defaults.bool(forKey: Key.modifierEnabled)
        modifierKey = ModifierChoice(rawValue: defaults.string(forKey: Key.modifierKey) ?? "") ?? .shift
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        quickActionsEnabled = defaults.bool(forKey: Key.quickActionsEnabled)
        dragOutMode = DragOutMode(rawValue: defaults.string(forKey: Key.dragOutMode) ?? "") ?? .copy
        closeWhenEmpty = defaults.bool(forKey: Key.closeWhenEmpty)
        detailLayout = DetailLayout(rawValue: defaults.string(forKey: Key.detailLayout) ?? "") ?? .grid
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        hotkeysEnabled = defaults.bool(forKey: Key.hotkeysEnabled)
        customScripts = defaults.data(forKey: Key.customScripts)
            .flatMap { try? JSONDecoder().decode([CustomScript].self, from: $0) } ?? []
    }

    var customActions: [any ShelfAction] {
        customScripts.map { ScriptAction(script: $0) }
    }
}
