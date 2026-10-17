import AppKit
import SwiftUI
import Combine
import Quartz
import PoxiDropCore

/// Ventanas de una estantería (la estantería, su detalle y su buscador) y todo lo que se hace con ellas.
@MainActor
final class ShelfWindowController: NSObject, NSWindowDelegate, ShelfDropTarget, QLPreviewPanelDataSource {
    let shelfID: Shelf.ID
    let model: ShelfModel
    unowned let manager: ShelfManager
    let panel: ShelfPanel
    private(set) var detailPanel: ShelfPanel?
    private var palettePanel: ShelfPanel?
    private var collapseTask: Task<Void, Never>?
    private var quickLookURLs: [URL] = []

    var store: ShelfStore { manager.store }
    var settings: AppSettings { manager.settings }

    init(shelf: Shelf, manager: ShelfManager) {
        shelfID = shelf.id
        model = ShelfModel(shelf: shelf)
        self.manager = manager
        panel = ShelfPanel(size: ShelfGeometry.shelfSize)
        super.init()
        let hosting = NSHostingView(rootView: ShelfView(model: model, commands: commands))
        hosting.frame = CGRect(origin: .zero, size: ShelfGeometry.shelfSize)
        let glass = GlassView(content: hosting, cornerRadius: ShelfGeometry.cornerRadius)
        glass.dropTarget = self
        panel.contentView = glass
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
    }

    var commands: ShelfCommands {
        ShelfCommands(
            close: { [weak self] clearing in self?.closeShelf(clearing: clearing) },
            showMenu: { [weak self] in self?.showActionsMenu() },
            toggleDetail: { [weak self] in self?.toggleDetail() },
            open: { [weak self] items in self?.open(items) },
            reveal: { [weak self] items in self?.reveal(items) },
            dragOperation: { [weak self] in self?.settings.dragOutMode == .move ? [.move, .copy] : .copy },
            dragEnded: { [weak self] items, operation in self?.dragEnded(items, operation) },
            itemMenu: { [weak self] item in self?.menu(for: item) }
        )
    }

    // MARK: Ventana

    var isVisible: Bool { panel.isVisible }

    func show(at origin: CGPoint) {
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func showAgain() {
        panel.orderFrontRegardless()
        if model.showingDetail { showDetail() }
    }

    func hide() {
        detailPanel?.orderOut(nil)
        panel.orderOut(nil)
    }

    func close() {
        hideDetail()
        palettePanel?.close()
        panel.close()
    }

    func refresh() {
        guard let shelf = store.shelf(shelfID) else { return }
        model.shelf = shelf
        model.selection = model.selection.intersection(shelf.items.map(\.id))
        if shelf.items.isEmpty { hideDetail() } else { layoutDetail() }
        applyDock()
    }

    func windowDidMove(_ notification: Notification) {
        if model.shelf.dock == nil {
            store.setOrigin(shelfID, panel.frame.origin)
        }
        layoutDetail()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        manager.activate(shelfID)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 49: // espacio
            quickLook(model.selectedItems)
            return true
        case 51 where !model.selection.isEmpty: // borrar
            removeSelected()
            return true
        default:
            return false
        }
    }

    // MARK: Soltar

    private func isOwnDrag(_ info: NSDraggingInfo) -> Bool {
        guard let window = (info.draggingSource as? NSView)?.window else { return false }
        return window === panel || window === detailPanel
    }

    func dropEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        guard !isOwnDrag(info) else { return [] }
        model.isDropTarget = true
        manager.activate(shelfID)
        if model.compact { expand() }
        if settings.quickActionsEnabled { manager.showQuickActions(for: self) }
        return .copy
    }

    func dropUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        isOwnDrag(info) ? [] : .copy
    }

    func dropExited() {
        model.isDropTarget = false
        manager.quickActions.scheduleHide()
        scheduleCollapse()
    }

    func performDrop(_ info: NSDraggingInfo) -> Bool {
        model.isDropTarget = false
        manager.quickActions.hide()
        guard !isOwnDrag(info) else { return false }
        manager.receive(info.draggingPasteboard, into: shelfID)
        return true
    }

    func hoverChanged(_ inside: Bool) {
        guard model.shelf.dock != nil else { return }
        if inside { expand() } else { scheduleCollapse() }
    }

    func performQuickAction(_ action: QuickAction, urls: [URL]) {
        if let name = action.service {
            share(urls, via: name)
        } else {
            manager.run(ZipAction(), urls: urls, in: shelfID)
        }
    }

    // MARK: Sacar

    private func dragEnded(_ items: [ShelfItem], _ operation: NSDragOperation) {
        guard !operation.isEmpty, !items.isEmpty else { return }
        let ids = Set(items.map(\.id))
        let everything = ids == Set(model.shelf.items.map(\.id))
        if operation.contains(.move) && settings.dragOutMode == .move {
            store.remove(ids, from: shelfID, deleteOwnedFiles: false)
        }
        if everything && settings.closeWhenEmpty {
            manager.close(shelfID)
        }
    }

    // MARK: Comandos

    private func closeShelf(clearing: Bool) {
        if clearing { store.clear(shelfID) }
        manager.close(shelfID)
    }

    func open(_ items: [ShelfItem]) {
        items.filter(\.exists).forEach { NSWorkspace.shared.open($0.url) }
    }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.filter(\.exists).map(\.url))
    }

    func removeSelected() {
        store.remove(model.selection, from: shelfID)
        model.selection = []
    }

    func addFromClipboard() {
        manager.addFromClipboard(to: shelfID)
    }

    func clearShelf() {
        store.clear(shelfID)
        model.selection = []
    }

    func copyToPasteboard(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        model.show("Copiado")
    }

    func copyPaths(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        model.show("Ruta copiada")
    }

    func transfer(_ urls: [URL], to folder: URL, named name: String, move: Bool) {
        do {
            if move {
                let moved = try FileOps.move(urls, to: folder)
                for (old, new) in zip(urls, moved) {
                    if let item = model.shelf.items.first(where: { $0.url == old }) {
                        store.replaceURL(of: item.id, in: shelfID, with: new)
                    }
                }
                model.show("Movido a \(name)")
            } else {
                _ = try FileOps.copy(urls, to: folder)
                model.show("Copiado a \(name)")
            }
        } catch {
            model.show(error.localizedDescription, isError: true)
        }
    }

    func chooseFolderAndTransfer(_ urls: [URL], move: Bool) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.prompt = move ? "Mover aquí" : "Copiar aquí"
        NSApp.activate()
        guard openPanel.runModal() == .OK, let folder = openPanel.url else { return }
        transfer(urls, to: folder, named: folder.lastPathComponent, move: move)
    }

    func share(_ urls: [URL], via name: NSSharingService.Name) {
        guard let service = NSSharingService(named: name), service.canPerform(withItems: urls) else {
            model.show("No se puede compartir así", isError: true)
            return
        }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    func showSharePicker(_ urls: [URL]) {
        guard let view = panel.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: CGRect(x: view.bounds.maxX - 32, y: view.bounds.maxY - 32, width: 22, height: 22),
                    of: view, preferredEdge: .maxY)
    }

    func toggleFavorite() {
        store.setFavorite(shelfID, !model.shelf.isFavorite)
    }

    func renameShelf() {
        guard let name = ask(title: "Nombre de la estantería", message: "Déjalo vacío para usar el nombre automático.",
                             value: model.shelf.customName ?? "", button: "Guardar") else { return }
        store.rename(shelfID, to: name)
    }

    func rename(_ item: ShelfItem) {
        guard let name = ask(title: "Cambiar nombre", message: "Nuevo nombre para «\(item.name)»:",
                             value: item.name, button: "Cambiar nombre") else { return }
        do {
            let url = try FileOps.rename(item.url, to: name)
            store.replaceURL(of: item.id, in: shelfID, with: url)
        } catch {
            model.show(error.localizedDescription, isError: true)
        }
    }

    private func ask(title: String, message: String, value: String, button: String) -> String? {
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = field
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancelar")
        NSApp.activate()
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    func showActionsMenu() {
        popUp(ActionMenuBuilder(controller: self).build())
    }

    private func popUp(_ menu: NSMenu) {
        guard let view = panel.contentView else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: view.bounds.maxX - 28, y: view.bounds.maxY - 30), in: view)
    }

    func menu(for item: ShelfItem) -> NSMenu? {
        if !model.selection.contains(item.id) { model.selection = [item.id] }
        let items = model.selectedItems
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: "Abrir", symbol: "arrow.up.forward.app") { [weak self] in self?.open(items) })
        menu.addItem(ClosureMenuItem(title: "Vista rápida", symbol: "eye") { [weak self] in self?.quickLook(items) })
        menu.addItem(ClosureMenuItem(title: "Mostrar en el Finder", symbol: "folder") { [weak self] in self?.reveal(items) })
        if items.count == 1 {
            menu.addItem(ClosureMenuItem(title: "Cambiar nombre…", symbol: "pencil") { [weak self] in self?.rename(items[0]) })
        }
        menu.addItem(.separator())
        let title = items.count == 1 ? "Quitar de la estantería" : "Quitar \(items.count) elementos"
        menu.addItem(ClosureMenuItem(title: title, symbol: "minus.circle") { [weak self] in self?.removeSelected() })
        return menu
    }

    // MARK: Buscador

    func showPalette() {
        let model = PaletteModel(entries: paletteEntries())
        let palette = ShelfPanel(size: CGSize(width: 300, height: 320))
        let hosting = NSHostingView(rootView: PaletteView(model: model, close: { [weak self] in self?.closePalette() }))
        hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 320)
        palette.contentView = GlassView(content: hosting, cornerRadius: 16)
        palette.onResignKey = { [weak self] in self?.closePalette() }
        let frame = panel.frame
        var origin = CGPoint(x: frame.maxX + 8, y: frame.maxY - 320)
        if let area = panel.screen?.visibleFrame, origin.x + 300 > area.maxX {
            origin.x = frame.minX - 308
        }
        palette.setFrameOrigin(origin)
        palettePanel?.close()
        palettePanel = palette
        palette.makeKeyAndOrderFront(nil)
    }

    private func closePalette() {
        palettePanel?.onResignKey = nil
        palettePanel?.close()
        palettePanel = nil
    }

    func paletteEntries() -> [PaletteEntry] {
        let items = model.selectedItems.filter(\.exists)
        let urls = items.map(\.url)
        var entries: [PaletteEntry] = []
        if !urls.isEmpty {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            entries += [
                PaletteEntry(id: "copy", title: "Copiar", symbol: "doc.on.doc") { [weak self] in self?.copyToPasteboard(urls) },
                PaletteEntry(id: "copy-path", title: "Copiar ruta", symbol: "link") { [weak self] in self?.copyPaths(urls) },
                PaletteEntry(id: "copy-desktop", title: "Copiar al Escritorio", symbol: "arrow.right.circle") { [weak self] in
                    self?.transfer(urls, to: desktop, named: "Escritorio", move: false)
                },
                PaletteEntry(id: "airdrop", title: "Compartir por AirDrop", symbol: "dot.radiowaves.left.and.right") { [weak self] in
                    self?.share(urls, via: .sendViaAirDrop)
                },
                PaletteEntry(id: "messages", title: "Enviar por Mensajes", symbol: "message") { [weak self] in
                    self?.share(urls, via: .composeMessage)
                },
                PaletteEntry(id: "mail", title: "Enviar por Mail", symbol: "envelope") { [weak self] in
                    self?.share(urls, via: .composeEmail)
                },
                PaletteEntry(id: "reveal", title: "Mostrar en el Finder", symbol: "folder") { [weak self] in self?.reveal(items) },
            ]
            entries += ActionRegistry.available(for: urls, custom: settings.customActions).map { action in
                PaletteEntry(id: action.id, title: action.title, symbol: action.symbol) { [weak self] in
                    guard let self else { return }
                    self.manager.run(action, urls: urls, in: self.shelfID)
                }
            }
        }
        entries.append(PaletteEntry(id: "clipboard", title: "Añadir desde el portapapeles", symbol: "doc.on.clipboard") { [weak self] in
            self?.addFromClipboard()
        })
        if !model.shelf.items.isEmpty {
            entries.append(PaletteEntry(id: "clear", title: "Vaciar estantería", symbol: "xmark.bin") { [weak self] in self?.clearShelf() })
        }
        return entries
    }

    // MARK: Detalle

    func toggleDetail() {
        model.showingDetail ? hideDetail() : showDetail()
    }

    func showDetail() {
        guard !model.shelf.items.isEmpty else { return }
        model.showingDetail = true
        if detailPanel == nil {
            let detail = ShelfPanel(size: CGSize(width: DetailGeometry.width, height: 200))
            let hosting = NSHostingView(rootView: DetailView(model: model, settings: settings, commands: commands))
            hosting.frame = CGRect(x: 0, y: 0, width: DetailGeometry.width, height: 200)
            let glass = GlassView(content: hosting, cornerRadius: 16)
            glass.dropTarget = self
            detail.contentView = glass
            detail.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
            detailPanel = detail
        }
        layoutDetail()
        if let detailPanel {
            panel.addChildWindow(detailPanel, ordered: .above)
            detailPanel.orderFrontRegardless()
        }
    }

    func hideDetail() {
        model.showingDetail = false
        guard let detailPanel else { return }
        panel.removeChildWindow(detailPanel)
        detailPanel.orderOut(nil)
    }

    func layoutDetail() {
        guard model.showingDetail, let detail = detailPanel else { return }
        let size = DetailGeometry.size(itemCount: model.shelf.items.count, layout: settings.detailLayout)
        var frame = CGRect(x: panel.frame.midX - size.width / 2, y: panel.frame.minY - size.height - 6,
                           width: size.width, height: size.height)
        if let area = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, area.minX + 6), area.maxX - frame.width - 6)
            if frame.minY < area.minY { frame.origin.y = panel.frame.maxY + 6 }
        }
        detail.setFrame(frame, display: true)
    }

    // MARK: Vista rápida

    func quickLook(_ items: [ShelfItem]) {
        quickLookURLs = items.filter(\.exists).map(\.url)
        guard !quickLookURLs.isEmpty, let preview = QLPreviewPanel.shared() else { return }
        NSApp.activate()
        preview.dataSource = self
        preview.reloadData()
        preview.makeKeyAndOrderFront(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { quickLookURLs.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated { quickLookURLs[index] as NSURL }
    }

    // MARK: Acoplar a un borde

    func dock(_ edge: DockEdge?) {
        store.setDock(shelfID, edge)
        if edge == nil {
            model.compact = false
            panel.setFrame(CGRect(origin: panel.frame.origin, size: ShelfGeometry.shelfSize), display: true, animate: true)
        } else {
            model.shelf.dock = edge
            collapse()
        }
    }

    private func applyDock() {
        guard model.shelf.dock != nil else {
            if model.compact {
                model.compact = false
                panel.setFrame(CGRect(origin: panel.frame.origin, size: ShelfGeometry.shelfSize), display: true)
            }
            return
        }
        if !model.isDropTarget && !panel.frame.contains(NSEvent.mouseLocation) && !model.compact {
            collapse()
        }
    }

    private func dockedFrame(size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.contains(panel.frame.center) } ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        let y = min(max(panel.frame.midY - size.height / 2, area.minY), area.maxY - size.height)
        let x = model.shelf.dock == .left ? area.minX : area.maxX - size.width
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    func expand() {
        guard model.shelf.dock != nil, model.compact else { return }
        collapseTask?.cancel()
        model.compact = false
        panel.setFrame(dockedFrame(size: ShelfGeometry.shelfSize), display: true, animate: true)
    }

    func collapse() {
        guard model.shelf.dock != nil else { return }
        hideDetail()
        model.compact = true
        panel.setFrame(dockedFrame(size: ShelfGeometry.compactSize), display: true, animate: true)
    }

    private func scheduleCollapse() {
        guard model.shelf.dock != nil else { return }
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled else { return }
            let mouse = NSEvent.mouseLocation
            guard !self.panel.frame.contains(mouse), !(self.detailPanel?.frame.contains(mouse) ?? false) else { return }
            self.collapse()
        }
    }
}
