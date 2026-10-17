import Foundation
import UniformTypeIdentifiers

public enum ItemKind: String, Codable, Sendable {
    case file, folder, image, text, link
}

/// Un elemento de una estantería.
public struct ShelfItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var url: URL
    /// Marcador para seguir encontrando el archivo aunque se mueva (solo archivos del usuario).
    public var bookmark: Data?
    /// `true` si el archivo es una copia propia de PoxiDrop (texto soltado, imágenes de webs, resultados de acciones).
    public var isOwned: Bool
    public var kind: ItemKind
    public var addedAt: Date

    public init(id: UUID = UUID(), url: URL, bookmark: Data? = nil, isOwned: Bool, kind: ItemKind, addedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.bookmark = bookmark
        self.isOwned = isOwned
        self.kind = kind
        self.addedAt = addedAt
    }

    public var name: String { url.lastPathComponent }
    public var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Tipo de elemento según lo que hay en disco y la extensión.
    public static func kind(of url: URL) -> ItemKind {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        if values?.isDirectory == true && values?.isPackage != true { return .folder }
        let ext = url.pathExtension.lowercased()
        if ext == "webloc" { return .link }
        guard let type = UTType(filenameExtension: ext) else { return .file }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .plainText) { return .text }
        return .file
    }
}
