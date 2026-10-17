import AppKit
import PoxiDropCore

/// Menú «…» de una estantería.
@MainActor
struct ActionMenuBuilder {
    let controller: ShelfWindowController

    func build() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let items = controller.model.selectedItems.filter(\.exists)
        let urls = items.map(\.url)

        menu.addItem(ClosureMenuItem(title: "Buscar acciones…", symbol: "magnifyingglass") { controller.showPalette() })
        menu.addItem(.separator())

        if !urls.isEmpty {
            let copyTitle = urls.count == 1 ? "Copiar «\(items[0].name)»" : "Copiar \(ShelfNaming.countLabel(for: items))"
            menu.addItem(ClosureMenuItem(title: copyTitle, symbol: "doc.on.doc") { controller.copyToPasteboard(urls) })
            menu.addItem(ClosureMenuItem(title: "Copiar ruta", symbol: "link") { controller.copyPaths(urls) })
            menu.addItem(.submenu(title: "Copiar a", symbol: "arrow.right.circle", menu: destinations(urls, move: false)))
            menu.addItem(.submenu(title: "Mover a", symbol: "arrow.forward.circle", menu: destinations(urls, move: true)))
            menu.addItem(.submenu(title: "Compartir", symbol: "square.and.arrow.up", menu: share(urls)))
            let actions = ActionRegistry.available(for: urls, custom: controller.settings.customActions)
            if !actions.isEmpty {
                menu.addItem(.submenu(title: "Todas las acciones", symbol: "ellipsis.circle", menu: grouped(actions, urls)))
            }
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Mostrar en el Finder", symbol: "folder") { controller.reveal(items) })
        }
        menu.addItem(ClosureMenuItem(title: "Añadir desde el portapapeles", symbol: "doc.on.clipboard") { controller.addFromClipboard() })
        if !controller.model.shelf.items.isEmpty {
            menu.addItem(ClosureMenuItem(title: "Vaciar estantería", symbol: "xmark.bin") { controller.clearShelf() })
        }
        menu.addItem(.separator())
        menu.addItem(.submenu(title: "Acoplar al borde", symbol: "sidebar.squares.right", menu: dockMenu()))
        let favorite = ClosureMenuItem(title: "Estantería favorita", symbol: "star") { controller.toggleFavorite() }
        favorite.state = controller.model.shelf.isFavorite ? .on : .off
        menu.addItem(favorite)
        menu.addItem(ClosureMenuItem(title: "Cambiar nombre de la estantería…", symbol: "character.cursor.ibeam") { controller.renameShelf() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Ajustes…", symbol: "gearshape") { controller.manager.openSettings() })
        return menu
    }

    private func destinations(_ urls: [URL], move: Bool) -> NSMenu {
        let menu = NSMenu()
        let places: [(String, String, FileManager.SearchPathDirectory)] = [
            ("Escritorio", "menubar.dock.rectangle", .desktopDirectory),
            ("Descargas", "arrow.down.circle", .downloadsDirectory),
            ("Documentos", "doc", .documentDirectory),
        ]
        for (name, symbol, directory) in places {
            guard let folder = FileManager.default.urls(for: directory, in: .userDomainMask).first else { continue }
            menu.addItem(ClosureMenuItem(title: name, symbol: symbol) { controller.transfer(urls, to: folder, named: name, move: move) })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Elegir carpeta…", symbol: "folder.badge.plus") { controller.chooseFolderAndTransfer(urls, move: move) })
        return menu
    }

    private func share(_ urls: [URL]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let services: [(String, String, NSSharingService.Name)] = [
            ("AirDrop", "dot.radiowaves.left.and.right", .sendViaAirDrop),
            ("Mensajes", "message", .composeMessage),
            ("Mail", "envelope", .composeEmail),
        ]
        for (title, symbol, name) in services {
            let item = ClosureMenuItem(title: title, symbol: symbol) { controller.share(urls, via: name) }
            item.isEnabled = NSSharingService(named: name)?.canPerform(withItems: urls) ?? false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Más…", symbol: "ellipsis") { controller.showSharePicker(urls) })
        return menu
    }

    private func grouped(_ actions: [any ShelfAction], _ urls: [URL]) -> NSMenu {
        let menu = NSMenu()
        for group in ActionGroup.allCases {
            let inGroup = actions.filter { $0.group == group }
            guard !inGroup.isEmpty else { continue }
            if menu.numberOfItems > 0 { menu.addItem(.separator()) }
            menu.addItem(.sectionHeader(title: group.rawValue))
            for action in inGroup {
                menu.addItem(ClosureMenuItem(title: action.title, symbol: action.symbol) {
                    controller.manager.run(action, urls: urls, in: controller.shelfID)
                })
            }
        }
        return menu
    }

    private func dockMenu() -> NSMenu {
        let menu = NSMenu()
        let current = controller.model.shelf.dock
        let left = ClosureMenuItem(title: "Izquierda", symbol: "sidebar.left") { controller.dock(.left) }
        left.state = current == .left ? .on : .off
        let right = ClosureMenuItem(title: "Derecha", symbol: "sidebar.right") { controller.dock(.right) }
        right.state = current == .right ? .on : .off
        menu.addItem(left)
        menu.addItem(right)
        if current != nil {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Desacoplar", symbol: "macwindow") { controller.dock(nil) })
        }
        return menu
    }
}
