import Foundation

public enum ShelfNaming {
    /// Nombre automático: el del archivo si hay uno solo, o «5 imágenes», «3 carpetas»…
    public static func automaticName(for items: [ShelfItem]) -> String {
        guard !items.isEmpty else { return "Estantería vacía" }
        if items.count == 1 { return items[0].name }
        return countLabel(for: items)
    }

    /// Texto de la píldora: «1 imagen», «5 imágenes», «2 elementos»…
    public static func countLabel(for items: [ShelfItem]) -> String {
        let count = items.count
        let kinds = Set(items.map(\.kind))
        let words: (singular: String, plural: String)
        if kinds.count == 1, let kind = kinds.first {
            switch kind {
            case .image: words = ("imagen", "imágenes")
            case .folder: words = ("carpeta", "carpetas")
            case .text: words = ("texto", "textos")
            case .link: words = ("enlace", "enlaces")
            case .file: words = ("archivo", "archivos")
            }
        } else {
            words = ("elemento", "elementos")
        }
        return "\(count) \(count == 1 ? words.singular : words.plural)"
    }
}
