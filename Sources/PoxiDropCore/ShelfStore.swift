import Foundation
import Combine
import CoreGraphics

public enum OwnedFolders {
    /// Crea una carpeta nueva y vacía dentro de `root` para guardar archivos propios.
    public static func make(in root: URL) throws -> URL {
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

/// Guarda las estanterías abiertas y las recientes, y los archivos propios de PoxiDrop.
@MainActor
public final class ShelfStore: ObservableObject {
    public static let recentLimit = 10

    @Published public private(set) var shelves: [Shelf] = []
    @Published public private(set) var recents: [Shelf] = []

    public let directory: URL
    public var itemsRoot: URL { directory.appendingPathComponent("Items", isDirectory: true) }
    private var stateURL: URL { directory.appendingPathComponent("estanterias.json") }

    private struct State: Codable {
        var shelves: [Shelf]
        var recents: [Shelf]
    }

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PoxiDrop", isDirectory: true)
    }

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory.resolvingSymlinksInPath()
        try? FileManager.default.createDirectory(at: itemsRoot, withIntermediateDirectories: true)
        load()
    }

    // MARK: Consultas

    public func shelf(_ id: Shelf.ID) -> Shelf? {
        shelves.first { $0.id == id }
    }

    public var favorite: Shelf? {
        shelves.first(where: \.isFavorite)
    }

    // MARK: Cambios

    @discardableResult
    public func createShelf(origin: CGPoint? = nil) -> Shelf.ID {
        let shelf = Shelf(origin: origin)
        shelves.append(shelf)
        save()
        return shelf.id
    }

    public func add(_ items: [ShelfItem], to id: Shelf.ID) {
        guard !items.isEmpty else { return }
        update(id) { shelf in
            var known = Set(shelf.items.map { $0.url.standardizedFileURL })
            for item in items where !known.contains(item.url.standardizedFileURL) {
                shelf.items.append(item)
                known.insert(item.url.standardizedFileURL)
            }
        }
    }

    /// Quita elementos. Con `deleteOwnedFiles` borra también las copias propias de PoxiDrop (nunca archivos del usuario).
    public func remove(_ itemIDs: Set<UUID>, from id: Shelf.ID, deleteOwnedFiles: Bool = true) {
        guard let shelf = shelf(id) else { return }
        if deleteOwnedFiles {
            deleteOwned(shelf.items.filter { itemIDs.contains($0.id) })
        }
        update(id) { $0.items.removeAll { itemIDs.contains($0.id) } }
    }

    public func clear(_ id: Shelf.ID) {
        guard let shelf = shelf(id) else { return }
        remove(Set(shelf.items.map(\.id)), from: id)
    }

    /// Cierra una estantería. La favorita se conserva; las demás pasan a recientes si tienen algo.
    public func close(_ id: Shelf.ID) {
        guard let index = shelves.firstIndex(where: { $0.id == id }) else { return }
        guard !shelves[index].isFavorite else { return }
        var closed = shelves.remove(at: index)
        if !closed.items.isEmpty {
            closed.origin = nil
            closed.dock = nil
            recents.insert(closed, at: 0)
            while recents.count > Self.recentLimit {
                deleteOwned(recents.removeLast().items)
            }
        }
        save()
    }

    @discardableResult
    public func reopen(recent id: Shelf.ID) -> Shelf.ID? {
        guard let index = recents.firstIndex(where: { $0.id == id }) else { return nil }
        let shelf = recents.remove(at: index)
        shelves.append(shelf)
        save()
        return shelf.id
    }

    public func clearRecents() {
        recents.forEach { deleteOwned($0.items) }
        recents = []
        save()
    }

    /// Solo puede haber una favorita.
    public func setFavorite(_ id: Shelf.ID, _ favorite: Bool) {
        for index in shelves.indices {
            if shelves[index].id == id {
                shelves[index].isFavorite = favorite
            } else if favorite {
                shelves[index].isFavorite = false
            }
        }
        save()
    }

    public func rename(_ id: Shelf.ID, to name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        update(id) { $0.customName = trimmed.isEmpty ? nil : trimmed }
    }

    public func setOrigin(_ id: Shelf.ID, _ origin: CGPoint?) {
        update(id) { $0.origin = origin }
    }

    public func setDock(_ id: Shelf.ID, _ dock: DockEdge?) {
        update(id) { $0.dock = dock }
    }

    /// Tras renombrar o mover un archivo desde la app.
    public func replaceURL(of itemID: UUID, in id: Shelf.ID, with url: URL) {
        update(id) { shelf in
            guard let index = shelf.items.firstIndex(where: { $0.id == itemID }) else { return }
            shelf.items[index].url = url
            if !shelf.items[index].isOwned {
                shelf.items[index].bookmark = try? url.bookmarkData()
            }
        }
    }

    /// Carpeta nueva para guardar archivos propios (texto soltado, resultados de acciones).
    public func makeOwnedFolder() throws -> URL {
        try OwnedFolders.make(in: itemsRoot)
    }

    // MARK: Guardado

    public func save() {
        guard let data = try? JSONEncoder().encode(State(shelves: shelves, recents: recents)) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        shelves = state.shelves.map(Self.resolvingBookmarks)
        recents = state.recents.map(Self.resolvingBookmarks)
    }

    private static func resolvingBookmarks(_ shelf: Shelf) -> Shelf {
        var shelf = shelf
        for index in shelf.items.indices {
            guard let bookmark = shelf.items[index].bookmark else { continue }
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], bookmarkDataIsStale: &stale) else { continue }
            shelf.items[index].url = url
            if stale { shelf.items[index].bookmark = try? url.bookmarkData() }
        }
        return shelf
    }

    private func update(_ id: Shelf.ID, _ change: (inout Shelf) -> Void) {
        guard let index = shelves.firstIndex(where: { $0.id == id }) else { return }
        change(&shelves[index])
        save()
    }

    /// Borra copias propias. Solo toca archivos dentro de `itemsRoot`.
    private func deleteOwned(_ items: [ShelfItem]) {
        let root = itemsRoot.resolvingSymlinksInPath().path + "/"
        for item in items where item.isOwned {
            let file = item.url.resolvingSymlinksInPath()
            guard file.path.hasPrefix(root) else { continue }
            try? FileManager.default.removeItem(at: file)
            let folder = file.deletingLastPathComponent()
            if folder.path + "/" != root,
               (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }
}
