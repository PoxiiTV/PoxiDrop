import AppKit
import SwiftUI
import PoxiDropCore

/// Capturas de la interfaz con datos de ejemplo, sin tocar las estanterías reales: `PoxiDrop --snapshot <carpeta>`.
@MainActor
enum Snapshots {
    static func render(to folder: URL) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let work = FileManager.default.temporaryDirectory.appendingPathComponent("poxidrop-snapshots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        let samples = makeSamples(in: work.appendingPathComponent("Muestras"))
        samples.filter(\.isImageFile).forEach { Thumbnails.shared.preload($0) }

        let settings = AppSettings(defaults: UserDefaults(suiteName: "dev.alexiis.poxidrop.snapshots") ?? .standard)
        settings.detailLayout = .grid
        let store = ShelfStore(directory: work.appendingPathComponent("Datos"))
        let manager = ShelfManager(store: store, settings: settings, openSettings: {})
        let offscreen = CGPoint(x: -8000, y: -8000)

        let id = store.createShelf(origin: offscreen)
        manager.importPayloads([.files(samples)], into: id)
        let empty = store.createShelf(origin: CGPoint(x: -8000, y: -7000))
        manager.sync()

        if let controller = manager.controller(for: id) {
            controller.model.isActive = true
            capture(controller.panel.contentView, to: folder.appendingPathComponent("estanteria.png"))
            controller.model.selection = Set(controller.model.shelf.items.prefix(2).map(\.id))
            controller.showDetail()
            capture(controller.detailPanel?.contentView, to: folder.appendingPathComponent("detalle.png"))
            settings.detailLayout = .list
            controller.layoutDetail()
            capture(controller.detailPanel?.contentView, to: folder.appendingPathComponent("detalle-lista.png"))
            controller.hideDetail()
            controller.showPalette()
            if let palette = NSApp.windows.compactMap({ $0 as? ShelfPanel }).first(where: { $0.frame.width == 300 }) {
                palette.setFrameOrigin(CGPoint(x: -8000, y: -6000))
                capture(palette.contentView, to: folder.appendingPathComponent("buscador.png"))
            }
        }
        if let controller = manager.controller(for: empty) {
            capture(controller.panel.contentView, to: folder.appendingPathComponent("estanteria-vacia.png"))
        }

        manager.quickActions.model.hovered = .airDrop
        manager.quickActions.show(below: CGRect(x: -8000, y: -5000, width: 170, height: 170))
        capture(manager.quickActions.contentView, to: folder.appendingPathComponent("acciones-directas.png"))

        for section in SettingsSection.allCases {
            let view = NSHostingView(rootView: SettingsView(settings: settings, store: store, section: section))
            view.frame = CGRect(x: 0, y: 0, width: 680, height: 470)
            let window = NSWindow(contentRect: CGRect(x: -8000, y: -4000, width: 680, height: 470),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.contentView = view
            window.orderFrontRegardless()
            capture(view, to: folder.appendingPathComponent("ajustes-\(section.id.lowercased()).png"), padding: 0)
            window.orderOut(nil)
        }
        print("Capturas en \(folder.path)")
    }

    /// Imágenes de colores, un texto y una carpeta para rellenar la estantería de ejemplo.
    private static func makeSamples(in folder: URL) -> [URL] {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let colors: [(String, NSColor, NSColor)] = [
            ("Atardecer.png", .systemOrange, .systemPink),
            ("Montaña.png", .systemTeal, .systemBlue),
            ("Bosque.png", .systemGreen, .systemMint),
        ]
        var urls: [URL] = []
        for (name, from, to) in colors {
            let image = NSImage(size: NSSize(width: 480, height: 320), flipped: false) { rect in
                NSGradient(starting: from, ending: to)?.draw(in: rect, angle: -40)
                return true
            }
            let url = folder.appendingPathComponent(name)
            if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
                urls.append(url)
            }
        }
        let notes = folder.appendingPathComponent("Notas.txt")
        try? "Ideas para el viaje".write(to: notes, atomically: true, encoding: .utf8)
        let project = folder.appendingPathComponent("Proyecto")
        try? FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        return urls + [notes, project]
    }

    /// Dibuja una vista sobre un fondo de escritorio de colores y la guarda como PNG.
    static func capture(_ view: NSView?, to url: URL, padding: CGFloat = 40) {
        guard let view else { return }
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let size = CGSize(width: view.bounds.width + padding * 2, height: view.bounds.height + padding * 2)
        let image = NSImage(size: size, flipped: false) { rect in
            if padding > 0 {
                NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.85, alpha: 1),
                           ending: NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.62, alpha: 1))?.draw(in: rect, angle: -35)
            }
            rep.draw(in: CGRect(x: padding, y: padding, width: view.bounds.width, height: view.bounds.height))
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

extension URL {
    var isImageFile: Bool {
        ["png", "jpg", "jpeg", "heic", "tiff", "gif"].contains(pathExtension.lowercased())
    }
}
