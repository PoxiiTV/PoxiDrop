import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox
import PoxiDropCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = AppSettings.shared
    private(set) var store: ShelfStore!
    private(set) var manager: ShelfManager!
    private var watcher: DragWatcher!
    private var statusItem: NSStatusItem?
    private let hotKeys = HotKeys()
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = ShelfStore(directory: ShelfStore.defaultDirectory)
        manager = ShelfManager(store: store, settings: settings) { [weak self] in self?.openSettings() }
        manager.sync()

        watcher = DragWatcher(settings: settings)
        watcher.onTrigger = { [weak self] point, trigger in self?.manager.openShelfForDrag(at: point, trigger: trigger) }
        watcher.onDragEnded = { [weak self] in self?.manager.dragSessionEnded() }
        watcher.start()

        settings.$showMenuBarIcon
            .sink { [weak self] visible in MainActor.assumeIsolated { self?.setStatusItem(visible: visible) } }
            .store(in: &subscriptions)
        settings.$hotkeysEnabled
            .sink { [weak self] enabled in MainActor.assumeIsolated { self?.updateHotKeys(enabled: enabled) } }
            .store(in: &subscriptions)
    }

    /// Al abrir la app otra vez desde Aplicaciones se muestran los ajustes (útil si no hay icono en la barra).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: Barra de menús

    private func setStatusItem(visible: Bool) {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "PoxiDrop")
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let shortcuts = settings.hotkeysEnabled
        let newShelf = ClosureMenuItem(title: "Nueva estantería", symbol: "plus.rectangle.on.rectangle", key: shortcuts ? "d" : "") { [weak self] in
            self?.manager.newShelf()
        }
        newShelf.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(newShelf)
        let clipboard = ClosureMenuItem(title: "Nueva estantería con el portapapeles", symbol: "doc.on.clipboard", key: shortcuts ? "v" : "") { [weak self] in
            self?.manager.addClipboardToNewShelf()
        }
        clipboard.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(clipboard)
        menu.addItem(ClosureMenuItem(title: "Estantería favorita", symbol: "star") { [weak self] in self?.manager.showFavorite() })

        let recents = NSMenu()
        if store.recents.isEmpty {
            let empty = NSMenuItem(title: "Sin estanterías recientes", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recents.addItem(empty)
        }
        for shelf in store.recents {
            recents.addItem(ClosureMenuItem(title: shelf.name, symbol: "clock") { [weak self] in self?.manager.reopenRecent(shelf.id) })
        }
        if !store.recents.isEmpty {
            recents.addItem(.separator())
            recents.addItem(ClosureMenuItem(title: "Borrar recientes", symbol: "trash") { [weak self] in self?.store.clearRecents() })
        }
        menu.addItem(.submenu(title: "Recientes", symbol: "clock.arrow.circlepath", menu: recents))
        menu.addItem(.separator())

        let toggle = ClosureMenuItem(title: manager.anyVisible ? "Ocultar estanterías" : "Mostrar estanterías", symbol: "eye", key: shortcuts ? "s" : "") { [weak self] in
            self?.manager.toggleAll()
        }
        toggle.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(toggle)
        menu.addItem(ClosureMenuItem(title: "Cerrar todas", symbol: "xmark.square") { [weak self] in self?.manager.closeAll() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Ajustes…", symbol: "gearshape", key: ",") { [weak self] in self?.openSettings() })
        menu.addItem(ClosureMenuItem(title: "Salir de PoxiDrop", symbol: "power", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: Atajos

    private func updateHotKeys(enabled: Bool) {
        guard enabled else {
            hotKeys.unregisterAll()
            return
        }
        let modifiers = UInt32(controlKey | optionKey)
        hotKeys.register([
            HotKey(keyCode: UInt32(kVK_ANSI_D), modifiers: modifiers) { [weak self] in self?.manager.newShelf() },
            HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: modifiers) { [weak self] in self?.manager.addClipboardToNewShelf() },
            HotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers) { [weak self] in self?.manager.toggleAll() },
        ])
    }

    // MARK: Ajustes

    func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings, store: store))
            let window = NSWindow(contentViewController: controller)
            window.title = "Ajustes de PoxiDrop"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
