import AppKit
import Combine
import PoxiDropCore

/// Coordina las estanterías: sus ventanas, lo que reciben y las acciones.
@MainActor
final class ShelfManager {
    let store: ShelfStore
    let settings: AppSettings
    let openSettings: () -> Void
    /// Las acciones directas se crean la primera vez que hacen falta.
    private var quickActionsController: QuickActionsController?
    var quickActions: QuickActionsController {
        if let quickActionsController { return quickActionsController }
        let created = QuickActionsController()
        quickActionsController = created
        return created
    }

    private var controllers: [Shelf.ID: ShelfWindowController] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var dragShelf: Shelf.ID?
    private var pruneTask: Task<Void, Never>?
    private(set) var activeShelf: Shelf.ID? {
        didSet { updateActive() }
    }

    init(store: ShelfStore, settings: AppSettings, openSettings: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.openSettings = openSettings
        store.$shelves
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.sync() } }
            .store(in: &subscriptions)
        settings.$detailLayout
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.controllers.values.forEach { $0.layoutDetail() } } }
            .store(in: &subscriptions)
    }

    func controller(for id: Shelf.ID) -> ShelfWindowController? {
        controllers[id]
    }

    /// Crea o quita ventanas para que coincidan con las estanterías guardadas.
    func sync() {
        let ids = Set(store.shelves.map(\.id))
        for (id, controller) in controllers where !ids.contains(id) {
            controller.close()
            controllers[id] = nil
        }
        for shelf in store.shelves {
            if let controller = controllers[shelf.id] {
                controller.refresh()
                continue
            }
            let controller = ShelfWindowController(shelf: shelf, manager: self)
            controllers[shelf.id] = controller
            controller.show(at: shelf.origin ?? ShelfGeometry.origin(centeredAt: defaultPoint, size: ShelfGeometry.shelfSize))
            controller.refresh()
        }
        updateActive()
        schedulePrune()
    }

    /// Olvida miniaturas y tamaños de archivos que ya no están en ninguna estantería.
    /// Se espera un segundo para que las ventanas recién cerradas no vuelvan a pedirlos.
    private func schedulePrune() {
        pruneTask?.cancel()
        pruneTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            let inUse = Set(self.store.shelves.flatMap { $0.items.map(\.url) })
            Thumbnails.shared.keep(only: inUse)
            SizeCache.shared.keep(only: inUse)
        }
    }

    func hideQuickActions(soon: Bool) {
        if soon { quickActionsController?.scheduleHide() } else { quickActionsController?.hide() }
    }

    private var defaultPoint: CGPoint {
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return CGPoint(x: area.maxX - 140, y: area.maxY - 140)
    }

    private func updateActive() {
        for (id, controller) in controllers {
            controller.model.isActive = id == activeShelf
        }
    }

    // MARK: Estanterías

    @discardableResult
    func newShelf(near point: CGPoint? = nil) -> Shelf.ID {
        let origin = ShelfGeometry.origin(centeredAt: point ?? NSEvent.mouseLocation, size: ShelfGeometry.shelfSize)
        let id = store.createShelf(origin: origin)
        activeShelf = id
        sync()
        return id
    }

    func activate(_ id: Shelf.ID) {
        activeShelf = id
    }

    func close(_ id: Shelf.ID) {
        if store.shelf(id)?.isFavorite == true {
            controllers[id]?.hide()
        }
        store.close(id)
        if activeShelf == id { activeShelf = nil }
        sync()
    }

    func closeAll() {
        for shelf in store.shelves { close(shelf.id) }
    }

    var anyVisible: Bool {
        controllers.values.contains { $0.isVisible }
    }

    func toggleAll() {
        let show = !anyVisible
        controllers.values.forEach { show ? $0.showAgain() : $0.hide() }
    }

    func showFavorite() {
        if let favorite = store.favorite {
            controllers[favorite.id]?.showAgain()
            activeShelf = favorite.id
        } else {
            let id = newShelf()
            store.setFavorite(id, true)
        }
    }

    func reopenRecent(_ id: Shelf.ID) {
        guard let reopened = store.reopen(recent: id) else { return }
        activeShelf = reopened
        sync()
    }

    // MARK: Arrastres

    /// El vigía pide una estantería durante un arrastre.
    func openShelfForDrag(at point: CGPoint, trigger: DragWatcher.Trigger) {
        var center = point
        if trigger == .notch, let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            center = CGPoint(x: point.x, y: screen.frame.maxY - screen.safeAreaInsets.top - ShelfGeometry.shelfSize.height / 2 - 10)
        }
        dragShelf = newShelf(near: center)
    }

    /// Al terminar el arrastre: fuera las acciones directas, y si la estantería que se abrió se quedó vacía, se cierra.
    func dragSessionEnded() {
        hideQuickActions(soon: true)
        guard let id = dragShelf else { return }
        dragShelf = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, let shelf = self.store.shelf(id), shelf.items.isEmpty,
                  self.controllers[id]?.model.busy != true else { return }
            self.close(id)
        }
    }

    func showQuickActions(for controller: ShelfWindowController) {
        quickActions.perform = { [weak controller] action, urls in controller?.performQuickAction(action, urls: urls) }
        quickActions.show(below: controller.panel.frame)
    }

    // MARK: Contenido

    func addClipboardToNewShelf() {
        addFromClipboard(to: newShelf())
    }

    func addFromClipboard(to id: Shelf.ID) {
        let payloads = PasteboardReader.payloads(from: .general)
        guard !payloads.isEmpty else {
            controllers[id]?.model.show("El portapapeles está vacío", isError: true)
            return
        }
        importPayloads(payloads, into: id)
    }

    func importPayloads(_ payloads: [DropPayload], into id: Shelf.ID) {
        let importer = DropImporter(itemsRoot: store.itemsRoot)
        var items: [ShelfItem] = []
        for payload in payloads {
            do {
                items += try importer.items(from: payload)
            } catch {
                controllers[id]?.model.show(error.localizedDescription, isError: true)
            }
        }
        store.add(items, to: id)
        sync()
    }

    /// Lo que se suelta en una estantería: archivos, o promesas de archivo (Fotos, Mail…), o lo que haya.
    func receive(_ pasteboard: NSPasteboard, into id: Shelf.ID) {
        let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if files.isEmpty, !promises.isEmpty {
            receivePromises(promises, into: id)
        } else {
            importPayloads(PasteboardReader.payloads(from: pasteboard), into: id)
        }
    }

    private func receivePromises(_ promises: [NSFilePromiseReceiver], into id: Shelf.ID) {
        guard let folder = try? OwnedFolders.make(in: store.itemsRoot) else { return }
        controllers[id]?.model.busy = true
        for promise in promises {
            promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: .main) { [weak self] url, error in
                MainActor.assumeIsolated {
                    self?.controllers[id]?.model.busy = false
                    if let error {
                        self?.controllers[id]?.model.show(error.localizedDescription, isError: true)
                    } else {
                        self?.importPayloads([.ownedFiles([url])], into: id)
                    }
                }
            }
        }
    }

    // MARK: Acciones

    func run(_ action: any ShelfAction, urls: [URL], in id: Shelf.ID) {
        guard !urls.isEmpty, let controller = controllers[id] else { return }
        controller.model.busy = true
        let root = store.itemsRoot
        Task { @MainActor [weak self] in
            defer { controller.model.busy = false }
            do {
                let folder = try OwnedFolders.make(in: root)
                let result = try await Task.detached(priority: .userInitiated) {
                    try await action.perform(urls, output: folder)
                }.value
                if result.files.isEmpty { try? FileManager.default.removeItem(at: folder) }
                self?.importPayloads([.ownedFiles(result.files)], into: id)
                if let text = result.copiedText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    controller.model.show("Texto copiado al portapapeles")
                } else if result.files.count == 1 {
                    controller.model.show("Listo: \(result.files[0].lastPathComponent)")
                } else if result.files.count > 1 {
                    controller.model.show("Listo: \(result.files.count) archivos")
                }
            } catch {
                controller.model.show(error.localizedDescription, isError: true)
            }
        }
    }
}
