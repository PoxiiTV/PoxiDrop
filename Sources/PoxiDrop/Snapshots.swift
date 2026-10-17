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
            capture(controller.panel.contentView, to: folder.appendingPathComponent("estanteria.png"), radius: ShelfGeometry.cornerRadius)
            controller.model.selection = Set(controller.model.shelf.items.prefix(2).map(\.id))
            controller.showDetail()
            capture(controller.detailPanel?.contentView, to: folder.appendingPathComponent("detalle.png"), radius: 16)
            settings.detailLayout = .list
            controller.layoutDetail()
            capture(controller.detailPanel?.contentView, to: folder.appendingPathComponent("detalle-lista.png"), radius: 16)
            controller.hideDetail()
            controller.showPalette()
            if let palette = NSApp.windows.compactMap({ $0 as? ShelfPanel }).first(where: { $0.frame.width == 300 }) {
                palette.setFrameOrigin(CGPoint(x: -8000, y: -6000))
                capture(palette.contentView, to: folder.appendingPathComponent("buscador.png"), radius: 16)
            }
        }
        if let controller = manager.controller(for: empty) {
            capture(controller.panel.contentView, to: folder.appendingPathComponent("estanteria-vacia.png"), radius: ShelfGeometry.cornerRadius)
        }

        let quickModel = QuickActionsModel()
        quickModel.hovered = .airDrop
        let quickRenderer = ImageRenderer(content: QuickActionsView(model: quickModel))
        quickRenderer.scale = 2
        if let image = quickRenderer.nsImage {
            compose(image, to: folder.appendingPathComponent("acciones-directas.png"), radius: nil)
        }

        for section in SettingsSection.allCases {
            let view = NSHostingView(rootView: SettingsView(settings: settings, store: store, section: section))
            view.frame = CGRect(x: 0, y: 0, width: 680, height: 470)
            let window = NSWindow(contentRect: CGRect(x: -8000, y: -4000, width: 680, height: 470),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.contentView = view
            window.orderFrontRegardless()
            capture(view, to: folder.appendingPathComponent("ajustes-\(section.id.lowercased()).png"), radius: 12, padding: 0)
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

    /// Captura una vista y la guarda como PNG bonita (ver `compose`).
    static func capture(_ view: NSView?, to url: URL, radius: CGFloat? = nil, padding: CGFloat = 40) {
        guard let view else { return }
        for _ in 0..<8 { autoreleasepool { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) } }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        compose(image, to: url, radius: radius, padding: padding)
    }

    /// Pone la imagen sobre una tarjeta de colores con esquinas redondeadas (transparente por fuera),
    /// recorta la propia imagen con su radio y le añade una sombra suave, como una ventana de verdad.
    static func compose(_ content: NSImage, to url: URL, radius: CGFloat?, padding: CGFloat = 40) {
        let inner = content.size
        let size = CGSize(width: inner.width + padding * 2, height: inner.height + padding * 2)
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let canvas = CGRect(origin: .zero, size: size)
        if padding > 0 {
            let card = NSBezierPath(roundedRect: canvas, xRadius: 28, yRadius: 28)
            NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.85, alpha: 1),
                       ending: NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.62, alpha: 1))?.draw(in: card, angle: -35)
        }
        let frame = CGRect(x: padding, y: padding, width: inner.width, height: inner.height)
        let shape = radius.map { NSBezierPath(roundedRect: frame, xRadius: $0, yRadius: $0) }
        if let shape, padding > 0 {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 18
            shadow.shadowOffset = NSSize(width: 0, height: -6)
            shadow.set()
            NSColor.black.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.saveGraphicsState()
        shape?.addClip()
        content.draw(in: frame)
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

extension URL {
    var isImageFile: Bool {
        ["png", "jpg", "jpeg", "heic", "tiff", "gif"].contains(pathExtension.lowercased())
    }
}
