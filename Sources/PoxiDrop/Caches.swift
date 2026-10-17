import AppKit
import QuickLookThumbnailing
import PoxiDropCore

/// Miniaturas de Quick Look con caché. Mientras se generan devuelve el icono del Finder.
@MainActor
final class Thumbnails: ObservableObject {
    static let shared = Thumbnails()

    @Published private(set) var images: [URL: NSImage] = [:]
    private var pending = Set<URL>()

    func image(for url: URL) -> NSImage {
        if let image = images[url] { return image }
        request(url)
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func cached(_ url: URL) -> NSImage? { images[url] }

    /// Carga una imagen al momento (para las capturas de prueba).
    func preload(_ url: URL) {
        if let image = NSImage(contentsOf: url) { images[url] = image }
    }

    private func request(_ url: URL) {
        guard !pending.contains(url) else { return }
        pending.insert(url)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 160, height: 160),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { Thumbnails.shared.images[url] = image }
            }
        }
    }
}

/// Tamaños de archivos y carpetas calculados en segundo plano.
@MainActor
final class SizeCache: ObservableObject {
    static let shared = SizeCache()

    @Published private(set) var sizes: [URL: Int64] = [:]
    private var pending = Set<URL>()

    func size(for url: URL) -> Int64? {
        if let size = sizes[url] { return size }
        guard !pending.contains(url) else { return nil }
        pending.insert(url)
        Task.detached(priority: .utility) {
            let size = FileSizes.size(of: url)
            await MainActor.run { SizeCache.shared.sizes[url] = size }
        }
        return nil
    }

    /// Suma de todos, o `nil` si alguno aún se está calculando.
    func total(for urls: [URL]) -> Int64? {
        var total: Int64 = 0
        for url in urls {
            guard let size = size(for: url) else { return nil }
            total += size
        }
        return total
    }
}
