import Foundation

/// Lo que puede llegar a una estantería.
public enum DropPayload: Sendable {
    /// Archivos o carpetas del usuario: se guardan como referencia, sin copiarlos.
    case files([URL])
    /// Archivos que ya están en la carpeta de PoxiDrop (promesas de Fotos o Mail, resultados de acciones).
    case ownedFiles([URL])
    /// Imagen sin archivo (por ejemplo, arrastrada desde una web).
    case image(Data, fileExtension: String)
    case text(String)
    case webLink(URL)
}

/// Convierte lo soltado en elementos de estantería. Lo que no es un archivo se guarda como archivo propio.
public struct DropImporter: Sendable {
    public let itemsRoot: URL

    public init(itemsRoot: URL) {
        self.itemsRoot = itemsRoot
    }

    public func items(from payload: DropPayload, now: Date = Date()) throws -> [ShelfItem] {
        switch payload {
        case .files(let urls):
            return urls.map { ShelfItem(url: $0, bookmark: try? $0.bookmarkData(), isOwned: false, kind: ShelfItem.kind(of: $0)) }
        case .ownedFiles(let urls):
            return urls.map { ShelfItem(url: $0, isOwned: true, kind: ShelfItem.kind(of: $0)) }
        case .image(let data, let fileExtension):
            let file = try OwnedFolders.make(in: itemsRoot).appendingPathComponent("Imagen \(Self.stamp(now)).\(fileExtension)")
            try data.write(to: file)
            return [ShelfItem(url: file, isOwned: true, kind: .image)]
        case .text(let text):
            let file = try OwnedFolders.make(in: itemsRoot).appendingPathComponent(Self.fileName(forText: text) + ".txt")
            try text.write(to: file, atomically: true, encoding: .utf8)
            return [ShelfItem(url: file, isOwned: true, kind: .text)]
        case .webLink(let link):
            let name = Self.fileName(forText: link.host() ?? "Enlace")
            let file = try OwnedFolders.make(in: itemsRoot).appendingPathComponent(name + ".webloc")
            let data = try PropertyListSerialization.data(fromPropertyList: ["URL": link.absoluteString], format: .xml, options: 0)
            try data.write(to: file)
            return [ShelfItem(url: file, isOwned: true, kind: .link)]
        }
    }

    /// Nombre de archivo a partir de la primera línea de un texto.
    static func fileName(forText text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        var cleaned = firstLine
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        let short = String(cleaned.prefix(40)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? "Texto" : short
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }
}
