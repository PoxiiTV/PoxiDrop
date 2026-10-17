import AppKit
import PoxiDropCore

/// Mide la memoria con un uso intensivo, sin tocar las estanterías reales: `PoxiDrop --medir`.
@MainActor
enum Benchmark {
    static func run() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("poxidrop-medir-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        report("Proceso vacío")
        let samples = autoreleasepool { makeFiles(in: work.appendingPathComponent("Archivos"), count: 30) }
        let settings = AppSettings(defaults: UserDefaults(suiteName: "dev.alexiis.poxidrop.medir") ?? .standard)
        let store = ShelfStore(directory: work.appendingPathComponent("Datos"))
        let manager = ShelfManager(store: store, settings: settings, openSettings: {})

        settle()
        report("Al arrancar")
        let rounds = ProcessInfo.processInfo.environment["POXIDROP_RONDAS"].flatMap(Int.init) ?? 4
        for round in 1...rounds {
            for index in 0..<50 { autoreleasepool {
                let id = store.createShelf(origin: CGPoint(x: -8000 - index, y: -8000))
                manager.importPayloads([.files(Array(samples.shuffled().prefix(6)))], into: id)
                manager.controller(for: id)?.showDetail()
            } }
            settle()
            report("Ronda \(round): 50 estanterías abiertas")
            // Como en el bucle normal de la app, que vacía la bolsa de liberación en cada evento.
            autoreleasepool {
                for shelf in store.shelves { manager.close(shelf.id) }
                store.clearRecents()
            }
            settle()
            report("Ronda \(round): todas cerradas")
            autoreleasepool {
                print("   controladores vivos: \(ShelfWindowController.alive) · ventanas en memoria: \(NSApp.windows.count) · miniaturas: \(Thumbnails.shared.images.count)")
            }
        }
        pauseIfAsked()
    }

    private static func pauseIfAsked() {
        guard let seconds = ProcessInfo.processInfo.environment["POXIDROP_PAUSA"].flatMap(Double.init) else { return }
        print("En pausa \(Int(seconds)) s (pid \(ProcessInfo.processInfo.processIdentifier))")
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private static func settle() {
        for _ in 0..<20 {
            autoreleasepool { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        }
    }

    private static func report(_ label: String) {
        autoreleasepool { printReport(label) }
    }

    private static func printReport(_ label: String) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let megabytes = result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
        let windows = NSApp.windows.filter(\.isVisible).count
        print(String(format: "%-40@ %6.1f MB  ventanas visibles: %d", label as NSString, megabytes, windows))
    }

    private static func makeFiles(in folder: URL, count: Int) -> [URL] {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (0..<count).compactMap { index in autoreleasepool {
            let image = NSImage(size: NSSize(width: 1200, height: 800), flipped: false) { rect in
                NSGradient(starting: .systemPink, ending: NSColor(hue: CGFloat(index) / CGFloat(count), saturation: 0.8, brightness: 0.9, alpha: 1))?
                    .draw(in: rect, angle: CGFloat(index * 12))
                return true
            }
            let url = folder.appendingPathComponent("Foto \(index).png")
            guard let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return nil }
            try? png.write(to: url)
            return url
        } }
    }
}
